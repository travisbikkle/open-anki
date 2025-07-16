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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Dashboard(totalCards: totalCards, learnedCards: learnedCards, deckCount: deckCount),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('最近刷题', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: recentDecksAsync.when(
                data: (decks) {
                  // 本地可变列表，删除时立即移除，防止 Dismissible 报错
                  final localDecks = List<DeckInfo>.from(decks);
                  return StatefulBuilder(
                    builder: (context, setState) => ListView.builder(
                      itemCount: localDecks.length,
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
                            await AnkiDb.deleteRecentDeck(deck.deckId); // 只删最近记录
                            ref.invalidate(recentDecksProvider);
                          },
                          child: DeckProgressTile(deck: deck),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 