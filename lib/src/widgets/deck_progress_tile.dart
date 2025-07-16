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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FutureBuilder<int>(
        future: (() async {
          // 通过 AppDb 查 apkg_path
          final allDecks = await AppDb.getAllDecks();
          final d = allDecks.firstWhere(
            (d) => (d['md5'] ?? d['id'].toString()) == deck.deckId,
            orElse: () => <String, dynamic>{},
          );
          if (d.isEmpty) return 0;
          final apkgPath = d['apkg_path'] as String;
          // 移除 parseApkg 的所有调用和相关 import
          return 0;
        })(),
        builder: (context, snapshot) {
          final cardCount = snapshot.data ?? 0;
          final double progress = cardCount > 0 ? (deck.currentIndex + 1) / cardCount : 0;
          return ListTile(
            title: Text(deck.deckName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('进度：${deck.currentIndex + 1}/$cardCount'),
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
          );
        },
      ),
    );
  }
} 