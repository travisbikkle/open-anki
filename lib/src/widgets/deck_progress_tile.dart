import 'package:flutter/material.dart';
import '../providers.dart';
import '../model.dart';
import '../pages/card_review_page.dart';

class DeckProgressTile extends StatelessWidget {
  final DeckInfo deck;
  const DeckProgressTile({required this.deck, super.key});

  @override
  Widget build(BuildContext context) {
    final cardCount = deck.cardCount;
    final learned = deck.currentIndex + 1;
    final double progress = cardCount > 0 ? learned / cardCount : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(deck.deckName),
          subtitle: Text('进度：$learned/$cardCount'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CardReviewPage(deckId: deck.deckId)),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              color: Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
} 