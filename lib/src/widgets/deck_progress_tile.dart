import 'package:flutter/material.dart';
import '../providers.dart';
import '../pages/card_review_page.dart';
import '../db.dart';
import 'package:open_anki/src/rust/api/simple.dart';

class DeckProgressTile extends StatelessWidget {
  final DeckInfo deck;
  const DeckProgressTile({required this.deck, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: (() async {
        final allDecks = await AppDb.getAllDecks();
        final d = allDecks.firstWhere(
          (d) => (d['md5'] ?? d['id'].toString()) == deck.deckId,
          orElse: () => <String, dynamic>{},
        );
        if (d.isEmpty) return 0;
        final apkgPath = d['apkg_path'] as String;
        return 0;
      })(),
      builder: (context, snapshot) {
        final cardCount = snapshot.data ?? 0;
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
      },
    );
  }
} 