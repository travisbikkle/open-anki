import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert'; // Added for jsonEncode and jsonDecode
import 'dart:typed_data'; // Added for Uint8List
import 'model.dart';
import 'package:path_provider/path_provider.dart'; // Added for getApplicationDocumentsDirectory
import 'dart:io'; // Added for File

class AppDb {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'anki_index.db');
    return openDatabase(
      path,
      version: 2, // 升级到版本2
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCardSchedulingTable(db);
          
          // 为现有卡片初始化调度参数
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final decks = await db.query('decks');
          for (final deck in decks) {
            final deckId = deck['md5'] as String;
            final appDocDir = await getApplicationDocumentsDirectory();
            final sqlitePath = join(appDocDir.path, 'anki_data', deckId, 'collection.sqlite');
            if (!File(sqlitePath).existsSync()) continue;
            
            final deckDb = await openDatabase(sqlitePath);
            final cardIds = await deckDb.rawQuery('SELECT id FROM notes');
            await deckDb.close();
            
            for (final row in cardIds) {
              final cardId = row['id'] as int;
              await db.insert(
                'card_scheduling',
                {
                  'card_id': cardId,
                  'stability': 0.0, // 新卡片，稳定性为0
                  'difficulty': 5.0,
                  'due': now,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
          }
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE decks (
        md5 TEXT PRIMARY KEY,
        apkg_path TEXT NOT NULL,
        user_deck_name TEXT,
        import_time INTEGER,
        media_map TEXT,
        version TEXT,
        card_count INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE progress (
        deck_id TEXT NOT NULL,
        current_card_id INTEGER,
        last_reviewed INTEGER,
        PRIMARY KEY(deck_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE recent_decks (
        deck_id TEXT PRIMARY KEY,
        last_reviewed INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE card_feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER NOT NULL,
        feedback INTEGER NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE study_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id TEXT NOT NULL,
        card_id INTEGER NOT NULL,
        study_time INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        nickname TEXT,
        avatar BLOB
      )
    ''');
    await db.execute('''
      CREATE TABLE card_scheduling (
        card_id INTEGER PRIMARY KEY,
        stability REAL NOT NULL,
        difficulty REAL NOT NULL,
        due INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createCardSchedulingTable(Database db) async {
    // 检查 card_scheduling 表是否已存在
    final tableExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='card_scheduling'"
    );
    
    if (tableExists.isEmpty) {
      // 创建 card_scheduling 表
      await db.execute('''
        CREATE TABLE card_scheduling (
          card_id INTEGER PRIMARY KEY,
          stability REAL NOT NULL,
          difficulty REAL NOT NULL,
          due INTEGER NOT NULL
        )
      ''');
    }
  }

  // 题库索引操作
  static Future<void> insertDeck(String apkgPath, String userDeckName, String md5, {Map<String, String>? mediaMap, String? version, int? cardCount}) async {
    final dbClient = await db;
    await dbClient.insert('decks', {
      'md5': md5,
      'apkg_path': apkgPath,
      'user_deck_name': userDeckName,
      'import_time': DateTime.now().millisecondsSinceEpoch,
      'media_map': mediaMap != null ? jsonEncode(mediaMap) : null,
      'version': version,
      'card_count': cardCount,
    });
  }

  static Future<int> deleteDeck({String? md5}) async {
    final dbClient = await db;
    if (md5 != null) {
      // 使用事务确保数据一致性
      return await dbClient.transaction((txn) async {
        // 删除 recent_decks 表中的记录
        await txn.delete('recent_decks', where: 'deck_id = ?', whereArgs: [md5]);
        // 删除 progress 表中的记录
        await txn.delete('progress', where: 'deck_id = ?', whereArgs: [md5]);
        // 删除 decks 表中的记录
        return await txn.delete('decks', where: 'md5 = ?', whereArgs: [md5]);
      });
    } else {
      throw ArgumentError('必须提供 md5');
    }
  }

  static Future<int> updateDeckName(String md5, String newName) async {
    final dbClient = await db;
    return await dbClient.update(
      'decks',
      {'user_deck_name': newName},
      where: 'md5 = ?',
      whereArgs: [md5],
    );
  }

  // 根据 ID 获取单个 deck
  static Future<DeckInfo?> getDeckById(String deckId) async {
    final dbClient = await db;
    final result = await dbClient.rawQuery('''
      SELECT 
        d.md5,
        d.user_deck_name,
        d.card_count,
        d.version,
        p.current_card_id,
        p.last_reviewed
      FROM decks d
      LEFT JOIN progress p ON d.md5 = p.deck_id
      WHERE d.md5 = ?
      LIMIT 1
    ''', [deckId]);
    
    if (result.isEmpty) return null;
    
    final deckMap = result.first;
    // 合并 decks 和 progress 的数据
    final mergedMap = {
      ...deckMap,
      'current_index': deckMap['current_card_id'] ?? 0,
    };
    return DeckInfo.fromMap(mergedMap);
  }

  static Future<List<DeckInfo>> getAllDecks() async {
    final dbClient = await db;
    final result = await dbClient.rawQuery('''
      SELECT 
        d.md5,
        d.user_deck_name,
        d.card_count,
        d.version,
        p.current_card_id,
        p.last_reviewed
      FROM decks d
      LEFT JOIN progress p ON d.md5 = p.deck_id
      ORDER BY d.import_time DESC
    ''');
    
    return result.map((map) {
      // 合并 decks 和 progress 的数据
      final deckMap = {
        ...map,
        'current_index': map['current_card_id'] ?? 0,
      };
      return DeckInfo.fromMap(deckMap);
    }).toList();
  }

  // 刷题进度操作
  static Future<void> saveProgress(String deckId, int cardId) async {
    final dbClient = await db;
    await dbClient.insert(
      'progress',
      {
        'deck_id': deckId,
        'current_card_id': cardId,
        'last_reviewed': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getProgress(String deckId) async {
    final dbClient = await db;
    final res = await dbClient.query('progress', where: 'deck_id = ?', whereArgs: [deckId]);
    return res.isNotEmpty ? res.first : null;
  }

  // 最近刷题记录
  static Future<void> upsertRecentDeck(String deckId) async {
    final dbClient = await db;
    await dbClient.insert(
      'recent_decks',
      {
        'deck_id': deckId,
        'last_reviewed': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<DeckInfo>> getRecentDecks({int limit = 10}) async {
    final dbClient = await db;
    final recentResults = await dbClient.query('recent_decks', orderBy: 'last_reviewed DESC', limit: limit);
    
    // 获取所有 deck 信息（包含进度）
    final allDecks = await getAllDecks();
    final deckMap = {for (var d in allDecks) d.deckId: d};
    
    // 只返回存在的 deck，过滤掉已删除的
    return recentResults
        .map((e) {
          final deckId = e['deck_id'] as String;
          return deckMap[deckId];
        })
        .whereType<DeckInfo>() // 过滤掉 null 值并确保类型正确
        .toList();
  }

  // 用户设置
  static Future<void> setUserSetting(String key, String value) async {
    final dbClient = await db;
    await dbClient.insert('user_settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getUserSetting(String key) async {
    final dbClient = await db;
    final res = await dbClient.query('user_settings', where: 'key = ?', whereArgs: [key]);
    return res.isNotEmpty ? res.first['value'] as String : null;
  }

  static Future<String> getUserName() async {
    String? name = await getUserSetting('user_name');
    if (name == null || name.isEmpty) {
      // 生成随机用户名
      final rand = (10000 + (DateTime.now().millisecondsSinceEpoch % 90000)).toString();
      name = 'Player$rand';
      await setUserName(name);
    }
    return name;
  }

  static Future<void> setUserName(String name) async {
    await setUserSetting('user_name', name);
  }

  static Future<Map<String, String>?> getDeckMediaMap(String md5) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'decks',
      columns: ['media_map'],
      where: 'md5 = ?',
      whereArgs: [md5],
    );
    if (result.isNotEmpty && result.first['media_map'] != null) {
      final mediaMapJson = result.first['media_map'] as String;
      final Map<String, dynamic> decoded = jsonDecode(mediaMapJson);
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    }
    return null;
  }

  // 保存卡片反馈
  static Future<void> saveCardFeedback(int cardId, int feedback) async {
    final dbClient = await db;
    await dbClient.insert(
      'card_feedback',
      {
        'card_id': cardId,
        'feedback': feedback,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // 查询某卡片所有反馈
  static Future<List<Map<String, dynamic>>> getCardFeedbacks(int cardId) async {
    final dbClient = await db;
    return await dbClient.query(
      'card_feedback',
      where: 'card_id = ?',
      whereArgs: [cardId],
      orderBy: 'timestamp DESC',
    );
  }

  // 学习日志
  static Future<void> logStudy(String deckId, int cardId) async {
    final dbClient = await db;
    await dbClient.insert('study_log', {
      'deck_id': deckId,
      'card_id': cardId,
      'study_time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<int> getTodayStudyCount() async {
    final dbClient = await db;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + Duration(days: 1).inMilliseconds;
    final res = await dbClient.rawQuery(
      'SELECT COUNT(DISTINCT card_id) as cnt FROM study_log WHERE study_time >= ? AND study_time < ?',
      [startOfDay, endOfDay],
    );
    return res.isNotEmpty ? (res.first['cnt'] as int? ?? 0) : 0;
  }

  static Future<int> getConsecutiveStudyDays() async {
    final dbClient = await db;
    // 查询所有有学习记录的日期（去重）
    final res = await dbClient.rawQuery(
      'SELECT DISTINCT strftime("%Y-%m-%d", datetime(study_time/1000, "unixepoch")) as day FROM study_log ORDER BY day DESC',
    );
    if (res.isEmpty) return 0;
    final now = DateTime.now();
    int streak = 0;
    for (int i = 0; i < res.length; i++) {
      final dayStr = res[i]['day'] as String;
      final day = DateTime.parse(dayStr);
      final expected = now.subtract(Duration(days: streak));
      if (day.year == expected.year && day.month == expected.month && day.day == expected.day) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  static Future<int> getTotalStudyDays() async {
    final dbClient = await db;
    final res = await dbClient.rawQuery(
      'SELECT MIN(study_time) as min_time FROM study_log',
    );
    if (res.isEmpty || res.first['min_time'] == null) return 0;
    final minTime = res.first['min_time'] as int;
    final firstDay = DateTime.fromMillisecondsSinceEpoch(minTime);
    final now = DateTime.now();
    final diff = now.difference(DateTime(firstDay.year, firstDay.month, firstDay.day)).inDays + 1;
    return diff;
  }

  static Future<DateTime?> getFirstStudyDate() async {
    final dbClient = await db;
    final res = await dbClient.rawQuery(
      'SELECT MIN(study_time) as min_time FROM study_log',
    );
    if (res.isEmpty || res.first['min_time'] == null) return null;
    final minTime = res.first['min_time'] as int;
    return DateTime.fromMillisecondsSinceEpoch(minTime);
  }

  // 用户头像相关
  static Future<void> setUserProfileAvatar(Uint8List avatarBytes) async {
    final dbClient = await db;
    await dbClient.insert(
      'user_profile',
      {'id': 1, 'avatar': avatarBytes},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Uint8List?> getUserProfileAvatar() async {
    final dbClient = await db;
    final res = await dbClient.query('user_profile', columns: ['avatar'], where: 'id = ?', whereArgs: [1]);
    if (res.isNotEmpty && res.first['avatar'] != null) {
      return res.first['avatar'] as Uint8List;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final dbClient = await db;
    final res = await dbClient.query('user_profile', where: 'id = ?', whereArgs: [1]);
    return res.isNotEmpty ? res.first : null;
  }

  // 卡片调度参数操作
  static Future<void> upsertCardScheduling(CardScheduling scheduling) async {
    final dbClient = await db;
    await dbClient.insert(
      'card_scheduling',
      scheduling.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<CardScheduling?> getCardScheduling(int cardId) async {
    final dbClient = await db;
    final res = await dbClient.query('card_scheduling', where: 'card_id = ?', whereArgs: [cardId]);
    return res.isNotEmpty ? CardScheduling.fromMap(res.first) : null;
  }

  static Future<void> deleteCardScheduling(int cardId) async {
    final dbClient = await db;
    await dbClient.delete('card_scheduling', where: 'card_id = ?', whereArgs: [cardId]);
  }

  static Future<List<CardScheduling>> getDueCards(int now) async {
    final dbClient = await db;
    final res = await dbClient.query('card_scheduling', where: 'due <= ?', whereArgs: [now]);
    return res.map((e) => CardScheduling.fromMap(e)).toList();
  }

  static Future<List<CardScheduling>> getAllCardScheduling() async {
    final dbClient = await db;
    final res = await dbClient.query('card_scheduling', orderBy: 'due ASC');
    return res.map((e) => CardScheduling.fromMap(e)).toList();
  }
} 