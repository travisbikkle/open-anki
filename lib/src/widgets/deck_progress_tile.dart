import 'package:flutter/material.dart';
import '../providers.dart';
import '../pages/card_review_page.dart';

class DeckProgressTile extends StatelessWidget {
  final DeckInfo deck;
  const DeckProgressTile({required this.deck, super.key});

  @override
  Widget build(BuildContext context) {
    final double progress = deck.cardCount > 0 ? (deck.currentIndex + 1) / deck.cardCount : 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(deck.deckName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('进度：${deck.currentIndex + 1}/${deck.cardCount}'),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress, minHeight: 6),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CardReviewPage(deckId: deck.deckId)),
          );
        },
      ),
    );
  }
} 