import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  final int totalCards;
  final int learnedCards;
  final int deckCount;
  const Dashboard({required this.totalCards, required this.learnedCards, required this.deckCount, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(label: '总卡片', value: totalCards.toString()),
          _StatItem(label: '已学习', value: learnedCards.toString()),
          _StatItem(label: '题库数', value: deckCount.toString()),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
} 