import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../constants.dart';

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
          Expanded(
            child: _DashboardCard(
              icon: Icons.menu_book,
              label: AppLocalizations.of(context)!.deckCount,
              value: deckCount.toString(),
              color: kMacaronColors[0],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DashboardCard(
              icon: Icons.psychology,
              label: AppLocalizations.of(context)!.learnedCards,
              value: learnedCards.toString(),
              color: kMacaronColors[2],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DashboardCard(
              icon: Icons.trending_up,
              label: AppLocalizations.of(context)!.totalCards,
              value: totalCards.toString(),
              color: kMacaronColors[4],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _DashboardCard({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
} 