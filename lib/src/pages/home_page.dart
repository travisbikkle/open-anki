import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../widgets/deck_progress_tile.dart';
import '../widgets/dashboard.dart';
import '../db.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decks = ref.watch(decksProvider);
    final totalCards = decks.fold<int>(0, (sum, d) => sum + d.cardCount);
    final learnedCards = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('首页')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Dashboard(totalCards: totalCards, learnedCards: learnedCards, deckCount: decks.length),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('最近刷题', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: decks.length,
              itemBuilder: (context, idx) {
                final deck = decks[idx];
                return Dismissible(
                  key: ValueKey(deck.deckId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await AnkiDb.deleteDeck(deck.deckId);
                    await ref.read(decksProvider.notifier).loadDecks();
                  },
                  child: DeckProgressTile(deck: deck),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 