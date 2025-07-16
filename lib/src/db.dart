import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
        await db.execute('''
          CREATE TABLE decks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            apkg_path TEXT NOT NULL,
            user_deck_name TEXT,
            md5 TEXT,
            import_time INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE progress (
            deck_id INTEGER NOT NULL,
            current_card_id INTEGER,
            last_reviewed INTEGER,
            PRIMARY KEY(deck_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE recent_decks (
            deck_id INTEGER PRIMARY KEY,
            last_reviewed INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE user_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  // 题库索引操作
  static Future<int> insertDeck(String apkgPath, String? userDeckName, String? md5) async {
    final dbClient = await db;
    print('insertDeck: $apkgPath, $userDeckName, $md5');
    final id = await dbClient.insert('decks', {
      'apkg_path': apkgPath,
      'user_deck_name': userDeckName,
      'md5': md5,
      'import_time': DateTime.now().millisecondsSinceEpoch,
    });
    print('insertDeck done, id=$id');
    return id;
  }

  static Future<int> deleteDeck({String? md5, int? id}) async {
    final dbClient = await db;
    if (md5 != null) {
      return await dbClient.delete('decks', where: 'md5 = ?', whereArgs: [md5]);
    } else if (id != null) {
      return await dbClient.delete('decks', where: 'id = ?', whereArgs: [id]);
    } else {
      throw ArgumentError('必须提供 md5 或 id');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllDecks() async {
    final dbClient = await db;
    final result = await dbClient.query('decks', orderBy: 'import_time DESC');
    print('getAllDecks: $result');
    return result;
  }

  // 刷题进度操作
  static Future<void> saveProgress(int deckId, int cardId) async {
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

  static Future<Map<String, dynamic>?> getProgress(int deckId) async {
    final dbClient = await db;
    final res = await dbClient.query('progress', where: 'deck_id = ?', whereArgs: [deckId]);
    return res.isNotEmpty ? res.first : null;
  }

  // 最近刷题记录
  static Future<void> upsertRecentDeck(int deckId) async {
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

  static Future<List<Map<String, dynamic>>> getRecentDecks({int limit = 10}) async {
    final dbClient = await db;
    return await dbClient.query('recent_decks', orderBy: 'last_reviewed DESC', limit: limit);
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
} 