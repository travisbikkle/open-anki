import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../widgets/deck_progress_tile.dart';
import '../widgets/dashboard.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decks = ref.watch(decksProvider);
    final totalCards = decks.fold<int>(0, (sum, d) => sum + d.cardCount);
    // 这里已学卡片数可后续扩展，现在用0
    final learnedCards = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('首页')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Dashboard(totalCards: totalCards, learnedCards: learnedCards, deckCount: decks.length),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('题库列表', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: decks.length,
              itemBuilder: (context, idx) => DeckProgressTile(deck: decks[idx]),
            ),
          ),
        ],
      ),
    );
  }
} 