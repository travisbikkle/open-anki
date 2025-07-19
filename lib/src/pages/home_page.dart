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
    final allDecksAsync = ref.watch(allDecksProvider);
    final recentDecksAsync = ref.watch(recentDecksProvider);
    final totalCards = allDecksAsync.asData?.value.fold<int>(0, (sum, d) => sum + d.cardCount) ?? 0;
    final deckCount = allDecksAsync.asData?.value.length ?? 0;
    final learnedCards = allDecksAsync.asData?.value.fold<int>(0, (sum, d) => sum + (d.currentIndex + 1)) ?? 0;
    return Scaffold(
      backgroundColor: const Color(0xffeaf6ff),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Dashboard(totalCards: totalCards, learnedCards: learnedCards, deckCount: deckCount),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text('最近刷题', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: recentDecksAsync.when(
                  data: (decks) {
                    final localDecks = List<DeckInfo>.from(decks);
                    return StatefulBuilder(
                      builder: (context, setState) => ListView.separated(
                        itemCount: localDecks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          if (idx >= localDecks.length) return const SizedBox.shrink();
                          final deck = localDecks[idx];
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
                              setState(() => localDecks.removeAt(idx));
                              ref.invalidate(recentDecksProvider);
                            },
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 1,
                              child: DeckProgressTile(deck: deck),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('加载失败: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 