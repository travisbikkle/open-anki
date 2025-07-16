import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model.dart';
import 'db.dart';

final notesProvider = StateNotifierProvider<NotesNotifier, List<AnkiNote>>((ref) => NotesNotifier());
final currentIndexProvider = StateProvider<int>((ref) => 0);
final decksProvider = StateNotifierProvider<DecksNotifier, List<DeckInfo>>((ref) => DecksNotifier());
final allDecksProvider = FutureProvider<List<DeckInfo>>((ref) async {
  final decks = await AnkiDb.getAllDecks();
  return decks.map((e) => DeckInfo(
    deckId: e['deck_id'] as String,
    deckName: (e['deck_name'] ?? '未命名题库') as String,
    cardCount: e['card_count'] as int,
    lastReviewed: e['last_reviewed'] as int?,
    currentIndex: (e['current_index'] ?? 0) as int,
  )).toList();
});
final recentDecksProvider = FutureProvider<List<DeckInfo>>((ref) async {
  final decks = await AnkiDb.getRecentDecks(limit: 10);
  return decks.map((e) => DeckInfo(
    deckId: e['deck_id'] as String,
    deckName: (e['deck_name'] ?? '未命名题库') as String,
    cardCount: e['card_count'] as int,
    lastReviewed: e['last_reviewed'] as int?,
    currentIndex: (e['current_index'] ?? 0) as int,
  )).toList();
});

class NotesNotifier extends StateNotifier<List<AnkiNote>> {
  NotesNotifier() : super([]);

  Future<void> loadFromDb(String deckId) async {
    final notes = await AnkiDb.getNotesByDeck(deckId);
    state = notes;
  }

  Future<void> setNotes(List<AnkiNote> notes, String deckId) async {
    await AnkiDb.clearNotesByDeck(deckId);
    await AnkiDb.insertNotes(notes, deckId);
    state = notes;
  }
}

class DeckInfo {
  final String deckId;
  final String deckName;
  final int cardCount;
  final int? lastReviewed;
  final int currentIndex;
  DeckInfo({required this.deckId, required this.deckName, required this.cardCount, this.lastReviewed, this.currentIndex = 0});
}

class DecksNotifier extends StateNotifier<List<DeckInfo>> {
  DecksNotifier() : super([]);

  Future<void> loadDecks() async {
    final decks = await AnkiDb.getAllDecks();
    // 按 lastReviewed 降序排列，取所有题库
    state = decks.map((e) => DeckInfo(
      deckId: e['deck_id'] as String,
      deckName: (e['deck_name'] ?? '未命名题库') as String,
      cardCount: e['card_count'] as int,
      lastReviewed: e['last_reviewed'] as int?,
      currentIndex: (e['current_index'] ?? 0) as int,
    ))
    .toList()
    ..sort((a, b) => (b.lastReviewed ?? 0).compareTo(a.lastReviewed ?? 0));
  }
} 