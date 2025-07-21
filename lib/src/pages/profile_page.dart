import 'package:flutter/material.dart';
import 'settings_page.dart';
import '../providers.dart';
import '../model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDecksAsync = ref.watch(allDecksProvider);
    int totalCards = 0;
    int deckCount = 0;
    if (allDecksAsync.asData != null) {
      final decks = allDecksAsync.asData!.value;
      deckCount = decks.length;
      for (final d in decks) {
        totalCards += d.cardCount;
      }
    }
    return FutureBuilder<List<int>>(
      future: Future.wait([
        AppDb.getConsecutiveStudyDays(),
        AppDb.getTodayStudyCount(),
      ]),
      builder: (context, snapshot) {
        final consecutiveDays = snapshot.data != null ? snapshot.data![0] : 0;
        final todayCount = snapshot.data != null ? snapshot.data![1] : 0;
        return Scaffold(
          backgroundColor: const Color(0xffeaf6ff),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.grey),
                onPressed: _showSettings,
              ),
            ],
          ),
          body: ListView(
            children: [
              // 顶部头像区
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue[200]!,
                            width: 3,
                            style: BorderStyle.solid,
                          ),
                        ),
                      ),
                      const Icon(Icons.person, size: 60, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 用户名、ID、加入时间
              Center(
                child: Column(
                  children: [
                    const Text('yu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                    Text('@ph.7t7DN1 · 2025年5月加入', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 学习统计
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatCard(icon: Icons.menu_book, label: '题库数', value: deckCount.toString()),
                    const _StatCard(icon: Icons.psychology, label: '学习天数', value: '54'),
                    _StatCard(icon: Icons.trending_up, label: '总卡片', value: totalCards.toString()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 概览区块
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _OverviewCard(icon: Icons.local_fire_department, label: '连续学习', value: consecutiveDays.toString() + '天', color: Colors.orange),
                    _OverviewCard(icon: Icons.flash_on, label: '今日学习', value: todayCount.toString(), color: Colors.amber),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 28),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _OverviewCard({required this.icon, required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
} 