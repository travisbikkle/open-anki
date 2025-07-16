import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'model.dart';

class AnkiDb {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'anki_cards.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY,
            guid TEXT,
            mid INTEGER,
            flds TEXT,
            deck_id TEXT,
            deck_name TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE progress (
            deck_id TEXT PRIMARY KEY,
            current_index INTEGER,
            last_reviewed INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS progress (
              deck_id TEXT PRIMARY KEY,
              current_index INTEGER
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE notes ADD COLUMN deck_id TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE notes ADD COLUMN deck_name TEXT');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE progress ADD COLUMN last_reviewed INTEGER');
        }
      },
    );
  }

  static Future<void> insertNotes(List<AnkiNote> notes, String deckId) async {
    final dbClient = await db;
    final batch = dbClient.batch();
    for (final note in notes) {
      batch.insert('notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<AnkiNote>> getNotesByDeck(String deckId) async {
    final dbClient = await db;
    final maps = await dbClient.query('notes', where: 'deck_id = ?', whereArgs: [deckId]);
    return maps.map((m) => AnkiNote.fromMap(m)).toList();
  }

  static Future<void> clearNotesByDeck(String deckId) async {
    final dbClient = await db;
    await dbClient.delete('notes', where: 'deck_id = ?', whereArgs: [deckId]);
  }

  static Future<List<Map<String, dynamic>>> getAllDecks() async {
    final dbClient = await db;
    return await dbClient.rawQuery('''
      SELECT n.deck_id, n.deck_name, COUNT(*) as card_count, p.last_reviewed
      FROM notes n
      LEFT JOIN progress p ON n.deck_id = p.deck_id
      GROUP BY n.deck_id, n.deck_name, p.last_reviewed
      ORDER BY p.last_reviewed DESC NULLS LAST
    ''');
  }

  static Future<void> deleteDeck(String deckId) async {
    final dbClient = await db;
    await dbClient.delete('notes', where: 'deck_id = ?', whereArgs: [deckId]);
    await dbClient.delete('progress', where: 'deck_id = ?', whereArgs: [deckId]);
  }

  static Future<void> saveProgress(String deckId, int index) async {
    final dbClient = await db;
    await dbClient.insert(
      'progress',
      {'deck_id': deckId, 'current_index': index},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> loadProgress(String deckId) async {
    final dbClient = await db;
    final result = await dbClient.query('progress', where: 'deck_id = ?', whereArgs: [deckId]);
    if (result.isNotEmpty) {
      return result.first['current_index'] as int;
    }
    return 0;
  }

  static Future<void> updateLastReviewed(String deckId) async {
    final dbClient = await db;
    await dbClient.insert(
      'progress',
      {'deck_id': deckId, 'last_reviewed': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
} 