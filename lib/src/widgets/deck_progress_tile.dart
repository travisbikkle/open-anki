import 'package:flutter/material.dart';
import '../providers.dart';
import '../pages/card_review_page.dart';

class DeckProgressTile extends StatelessWidget {
  final DeckInfo deck;
  const DeckProgressTile({required this.deck, super.key});

  @override
  Widget build(BuildContext context) {
    // 进度可后续扩展，现在用0
    final double progress = 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(deck.deckName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('共${deck.cardCount}题'),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress, minHeight: 6),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CardReviewPage(deckId: deck.deckId)),
            );
          },
        ),
      ),
    );
  }
} 