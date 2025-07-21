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
      version: 1,
      onCreate: (db, version) async {
        // 创建题库表
        await db.execute('''
          CREATE TABLE decks (
            md5 TEXT PRIMARY KEY,
            apkg_path TEXT NOT NULL,
            user_deck_name TEXT,
            import_time INTEGER,
            media_map TEXT,
            version TEXT,
            card_count INTEGER,
            total_learned INTEGER DEFAULT 0
          )
        ''');

        // 创建进度表
        await db.execute('''
          CREATE TABLE progress (
            deck_id TEXT NOT NULL,
            current_card_id INTEGER,
            last_reviewed INTEGER,
            PRIMARY KEY(deck_id)
          )
        ''');

        // 创建最近题库表
        await db.execute('''
          CREATE TABLE recent_decks (
            deck_id TEXT PRIMARY KEY,
            last_reviewed INTEGER
          )
        ''');

        // 创建用户设置表
        await db.execute('''
          CREATE TABLE user_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');

        // 创建卡片反馈表
        await db.execute('''
          CREATE TABLE card_feedback (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            card_id INTEGER NOT NULL,
            feedback INTEGER NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');

        // 创建学习日志表
        await db.execute('''
          CREATE TABLE study_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            deck_id TEXT NOT NULL,
            card_id INTEGER NOT NULL,
            study_time INTEGER NOT NULL
          )
        ''');

        // 创建用户档案表
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY,
            nickname TEXT,
            avatar BLOB
          )
        ''');

        // 创建卡片调度表
        await db.execute('''
          CREATE TABLE card_scheduling (
            card_id INTEGER PRIMARY KEY,
            stability REAL NOT NULL,
            difficulty REAL NOT NULL,
            due INTEGER NOT NULL
          )
        ''');

        // 创建学习计划设置表
        await db.execute('''
          CREATE TABLE study_plan_settings (
            deck_id TEXT PRIMARY KEY,
            new_rrr_per_day INTEGER NOT NULL DEFAULT 20,
            reviews_per_day INTEGER NOT NULL DEFAULT 100,
            enable_time_limit INTEGER NOT NULL DEFAULT 0,
            study_time_minutes INTEGER NOT NULL DEFAULT 30,
            default_mode INTEGER NOT NULL DEFAULT 1
          )
        ''');

        // 创建每日学习统计表
        await db.execute('''
          CREATE TABLE daily_study_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            deck_id TEXT NOT NULL,
            date INTEGER NOT NULL,
            new_cards_learned INTEGER NOT NULL DEFAULT 0,
            cards_reviewed INTEGER NOT NULL DEFAULT 0,
            total_time INTEGER NOT NULL DEFAULT 0,
            correct_count INTEGER NOT NULL DEFAULT 0,
            total_count INTEGER NOT NULL DEFAULT 0,
            UNIQUE(deck_id, date)
          )
        ''');

        // 创建卡片状态表
        await db.execute('''
          CREATE TABLE card_states (
            card_id INTEGER PRIMARY KEY,
            deck_id TEXT NOT NULL,
            state INTEGER NOT NULL DEFAULT 0,
            first_learned INTEGER,
            last_reviewed INTEGER,
            FOREIGN KEY(deck_id) REFERENCES decks(md5)
          )
        ''');

        // 创建卡片表
        await db.execute('''
          CREATE TABLE cards (
            card_id INTEGER PRIMARY KEY,
            deck_id TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 无升级逻辑
      },
    );
  }

  // 删除 _createTables 方法（未被调用，已被 onCreate 替代）

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

  // 删除题库 - 完整版本
  static Future<void> deleteDeck(String deckId) async {
    final dbClient = await db;
    await dbClient.transaction((txn) async {
      // 先查出该牌组下所有卡片ID
      final cardIdRows = await txn.query('cards', where: 'deck_id = ?', whereArgs: [deckId]);
      final cardIds = cardIdRows.map((e) => e['card_id'] as int).toList();
      String idList = cardIds.isNotEmpty ? '(${List.filled(cardIds.length, '?').join(',')})' : '(NULL)';

      // 删除题库相关的所有数据
      await txn.delete('recent_decks', where: 'deck_id = ?', whereArgs: [deckId]);
      await txn.delete('progress', where: 'deck_id = ?', whereArgs: [deckId]);
      await txn.delete('decks', where: 'md5 = ?', whereArgs: [deckId]);
      await txn.delete('study_plan_settings', where: 'deck_id = ?', whereArgs: [deckId]);
      await txn.delete('daily_study_stats', where: 'deck_id = ?', whereArgs: [deckId]);
      await txn.delete('cards', where: 'deck_id = ?', whereArgs: [deckId]); // 删除卡片映射
      // 删除卡片相关的调度和状态
      if (cardIds.isNotEmpty) {
        await txn.delete('card_scheduling', where: 'card_id IN $idList', whereArgs: cardIds);
        await txn.delete('card_states', where: 'card_id IN $idList', whereArgs: cardIds);
      }
    });

    // 删除题库文件
    final appDocDir = await getApplicationDocumentsDirectory();
    final deckDir = Directory('${appDocDir.path}/anki_data/$deckId');
    if (await deckDir.exists()) {
      await deckDir.delete(recursive: true);
    }
  }

  // 重命名题库
  static Future<void> renameDeck(String deckId, String newName) async {
    final dbClient = await db;
    await dbClient.update(
      'decks',
      {'user_deck_name': newName},
      where: 'md5 = ?',
      whereArgs: [deckId],
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
        d.total_learned,
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
        d.total_learned,
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

  // 学习计划设置操作
  static Future<void> saveStudyPlanSettings(String deckId, StudyPlanSettings settings) async {
    final dbClient = await db;
    await dbClient.insert(
      'study_plan_settings',
      {
        'deck_id': deckId,
        'new_cards_per_day': settings.newCardsPerDay,
        'reviews_per_day': settings.reviewsPerDay,
        'enable_time_limit': settings.enableTimeLimit ? 1 : 0,
        'study_time_minutes': settings.studyTimeMinutes,
        'default_mode': settings.defaultMode.index,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<StudyPlanSettings> getStudyPlanSettings(String deckId) async {
    final dbClient = await db;
    final res = await dbClient.query(
      'study_plan_settings',
      where: 'deck_id = ?',
      whereArgs: [deckId],
    );
    if (res.isEmpty) {
      return const StudyPlanSettings(); // 返回默认设置
    }
    return StudyPlanSettings(
      newCardsPerDay: res.first['new_cards_per_day'] as int,
      reviewsPerDay: res.first['reviews_per_day'] as int,
      enableTimeLimit: res.first['enable_time_limit'] == 1,
      studyTimeMinutes: res.first['study_time_minutes'] as int,
      defaultMode: StudyMode.values[res.first['default_mode'] as int],
    );
  }

  // 每日学习统计操作
  static Future<void> updateDailyStats(DailyStudyStats stats) async {
    final dbClient = await db;
    final startOfDay = DateTime(stats.date.year, stats.date.month, stats.date.day).millisecondsSinceEpoch;
    
    await dbClient.insert(
      'daily_study_stats',
      {
        'deck_id': stats.deckId,
        'date': startOfDay,
        'new_cards_learned': stats.newCardsLearned,
        'cards_reviewed': stats.cardsReviewed,
        'total_time': stats.totalTime,
        'correct_count': stats.correctCount,
        'total_count': stats.totalCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<DailyStudyStats?> getTodayStats(String deckId) async {
    final dbClient = await db;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    
    final res = await dbClient.query(
      'daily_study_stats',
      where: 'deck_id = ? AND date = ?',
      whereArgs: [deckId, startOfDay],
    );
    
    if (res.isEmpty) return null;
    return DailyStudyStats.fromMap(res.first);
  }

  // 卡片状态操作
  static Future<void> updateCardState(int cardId, String deckId, CardState state) async {
    final dbClient = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await dbClient.insert(
      'card_states',
      {
        'card_id': cardId,
        'deck_id': deckId,
        'state': state.index,
        'last_reviewed': now,
        'first_learned': state == CardState.newCard ? now : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<CardState> getCardState(int cardId) async {
    final dbClient = await db;
    final res = await dbClient.query(
      'card_states',
      where: 'card_id = ?',
      whereArgs: [cardId],
    );
    
    if (res.isEmpty) {
      return CardState.newCard; // 默认为新卡片
    }
    return CardState.values[res.first['state'] as int];
  }

  // 获取学习统计
  static Future<Map<String, int>> getDeckStats(String deckId) async {
    final dbClient = await db;
    
    // 获取各状态的卡片数量
    final res = await dbClient.rawQuery('''
      SELECT state, COUNT(*) as count
      FROM card_states
      WHERE deck_id = ?
      GROUP BY state
    ''', [deckId]);
    
    final stats = {
      'new': 0,
      'learning': 0,
      'review': 0,
      'done': 0,
    };
    
    for (final row in res) {
      final state = CardState.values[row['state'] as int];
      final count = row['count'] as int;
      switch (state) {
        case CardState.newCard:
          stats['new'] = count;
          break;
        case CardState.learning:
          stats['learning'] = count;
          break;
        case CardState.review:
          stats['review'] = count;
          break;
        case CardState.done:
          stats['done'] = count;
          break;
      }
    }
    
    return stats;
  }

  // 根据学习模式获取卡片
  static Future<List<int>> getCardsForMode(String deckId, StudyMode mode, {int limit = 50}) async {
    final dbClient = await db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    switch (mode) {
      case StudyMode.learn:
        // 获取新卡片，按ID排序
        final res = await dbClient.rawQuery('''
          SELECT cs.card_id
          FROM card_states cs
          WHERE cs.deck_id = ? AND cs.state = ?
          ORDER BY cs.card_id
          LIMIT ?
        ''', [deckId, CardState.newCard.index, limit]);
        return res.map((e) => e['card_id'] as int).toList();
        
      case StudyMode.review:
        // 获取到期的复习卡片
        return (await getDueCards(now)).map((e) => e.cardId).toList();
        
      case StudyMode.preview:
        // 获取所有卡片，按ID排序
        final res = await dbClient.rawQuery('''
          SELECT DISTINCT card_id
          FROM card_states
          WHERE deck_id = ?
          ORDER BY card_id
        ''', [deckId]);
        return res.map((e) => e['card_id'] as int).toList();
        
      case StudyMode.custom:
        // 混合模式：新卡片 + 复习卡片，各取一半
        final newCards = await getCardsForMode(deckId, StudyMode.learn, limit: limit ~/ 2);
        final reviewCards = await getCardsForMode(deckId, StudyMode.review, limit: limit ~/ 2);
        return [...newCards, ...reviewCards];
    }
  }

  // 检查今天的学习限制
  static Future<bool> canStudyMore(String deckId) async {
    final settings = await getStudyPlanSettings(deckId);
    final stats = await getTodayStats(deckId);
    
    if (stats == null) return true;
    
    // 检查新卡片限制
    if (stats.newCardsLearned >= settings.newCardsPerDay) return false;
    
    // 检查复习限制
    if (stats.cardsReviewed >= settings.reviewsPerDay) return false;
    
    // 检查时间限制
    if (settings.enableTimeLimit && 
        stats.totalTime >= settings.studyTimeMinutes * 60) return false;
    
    return true;
  }

  // 新增：增加总学习数量
  static Future<void> incrementTotalLearned(String deckId) async {
    final dbClient = await db;
    await dbClient.rawUpdate(
      'UPDATE decks SET total_learned = total_learned + 1 WHERE md5 = ?',
      [deckId]
    );
  }

  // 插入卡片与牌组的映射
  static Future<void> insertCardMapping(int cardId, String deckId) async {
    final dbClient = await db;
    await dbClient.insert(
      'cards',
      {'card_id': cardId, 'deck_id': deckId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 查询某牌组下所有卡片ID
  static Future<List<int>> getCardIdsByDeck(String deckId) async {
    final dbClient = await db;
    final res = await dbClient.query('cards', where: 'deck_id = ?', whereArgs: [deckId]);
    return res.map((e) => e['card_id'] as int).toList();
  }
} 