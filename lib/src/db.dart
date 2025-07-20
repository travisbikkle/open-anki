import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert'; // Added for jsonEncode and jsonDecode
import 'model.dart';

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
      version: 1, // 重新开始，使用版本1
      onCreate: (db, version) async {
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
      },
    );
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
      return await dbClient.delete('decks', where: 'md5 = ?', whereArgs: [md5]);
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
    
    return recentResults.map((e) {
      final deckId = e['deck_id'] as String;
      final deck = deckMap[deckId];
      if (deck != null) {
        return deck;
      } else {
        // 如果找不到对应的 deck，返回一个默认的
        return DeckInfo(
          deckId: deckId,
          deckName: '未知题库',
          cardCount: 0,
          lastReviewed: e['last_reviewed'] as int?,
          currentIndex: 0,
        );
      }
    }).toList();
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
} 