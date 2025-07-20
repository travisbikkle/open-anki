import 'package:flutter/material.dart';
import '../providers.dart';
import '../model.dart';
import '../pages/card_review_page.dart';

class DeckProgressTile extends StatelessWidget {
  final DeckInfo deck;
  final VoidCallback? onTap;
  const DeckProgressTile({required this.deck, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final cardCount = deck.cardCount;
    final learned = deck.currentIndex + 1;
    final double progress = cardCount > 0 ? learned / cardCount : 0;
    
    return GestureDetector(
      onTap: onTap ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CardReviewPage(deckId: deck.deckId)),
        );
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(deck.deckName),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Container(
                height: 16,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 16,
                        backgroundColor: Colors.grey[200],
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      '$learned/$cardCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
} 