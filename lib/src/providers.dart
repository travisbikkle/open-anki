import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model.dart';
import 'db.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

final currentIndexProvider = StateProvider<int>((ref) => 0);

final allDecksProvider = FutureProvider<List<DeckInfo>>((ref) async {
  final decks = await AppDb.getAllDecks();
  final List<DeckInfo> result = [];
  for (final e in decks) {
    final deckId = (e['md5'] ?? e['id'].toString()) as String;
    final deckName = (e['user_deck_name'] ?? '未命名题库') as String;
    int cardCount = 0;
    try {
      // 查找该题库的sqlite文件
      final appDocDir = await getApplicationDocumentsDirectory();
      final deckDir = join(appDocDir.path, 'anki_data', deckId);
      final sqlitePath = join(deckDir, 'collection.sqlite');
      if (await File(sqlitePath).exists()) {
        final db = await openDatabase(sqlitePath);
        final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM notes');
        cardCount = res.first['cnt'] as int? ?? 0;
        await db.close();
      }
    } catch (e) {
      cardCount = 0;
    }
    result.add(DeckInfo(
      deckId: deckId,
      deckName: deckName,
      cardCount: cardCount,
      lastReviewed: null,
      currentIndex: 0,
    ));
  }
  return result;
});

final recentDecksProvider = FutureProvider<List<DeckInfo>>((ref) async {
  final recents = await AppDb.getRecentDecks(limit: 10);
  // 需 join decks 表获取完整信息
  final allDecks = await AppDb.getAllDecks();
  final deckMap = {for (var d in allDecks) (d['md5'] ?? d['id'].toString()): d};
  return recents.map((e) {
    final deck = deckMap[e['deck_id'].toString()];
    return DeckInfo(
      deckId: (deck?['md5'] ?? deck?['id']?.toString() ?? e['deck_id'].toString()) as String,
      deckName: (deck?['user_deck_name'] ?? '未命名题库') as String,
      cardCount: 0, // TODO: FFI
      lastReviewed: e['last_reviewed'] as int?,
      currentIndex: 0, // TODO: FFI
    );
  }).toList();
});

// 卡片加载相关 provider/方法，建议直接在页面用 FFI 查 collection.sqlite，暂不在此提供
// final notesProvider = ...
// class NotesNotifier ...

class DeckInfo {
  final String deckId;
  final String deckName;
  final int cardCount;
  final int? lastReviewed;
  final int currentIndex;
  DeckInfo({required this.deckId, required this.deckName, required this.cardCount, this.lastReviewed, this.currentIndex = 0});
}

// class DecksNotifier ... // 如需全局刷新可后续补充 