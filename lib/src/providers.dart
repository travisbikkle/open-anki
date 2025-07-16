import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model.dart';
import 'db.dart';

final currentIndexProvider = StateProvider<int>((ref) => 0);

final allDecksProvider = FutureProvider<List<DeckInfo>>((ref) async {
  final decks = await AppDb.getAllDecks();
  // 这里 cardCount/lastReviewed/currentIndex 需后续补充（如 FFI 查 collection.sqlite），暂设为0/null
  return decks.map((e) => DeckInfo(
    deckId: (e['md5'] ?? e['id'].toString()) as String,
    deckName: (e['user_deck_name'] ?? '未命名题库') as String,
    cardCount: 0, // TODO: 通过 FFI 查 collection.sqlite 获取卡片数
    lastReviewed: null, // TODO: 通过 AppDb 或 FFI 获取
    currentIndex: 0, // TODO: 通过 AppDb 或 FFI 获取
  )).toList();
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