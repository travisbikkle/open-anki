import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const _FontSettingSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const Positioned(
                    bottom: 12,
                    right: 12,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.add, color: Colors.blue),
                    ),
                  ),
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
          // 课程/关注/粉丝
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _StatCard(icon: Icons.flag, label: '课程', value: '2'),
                _StatCard(icon: Icons.people, label: '关注', value: '1'),
                _StatCard(icon: Icons.person, label: '关注者', value: '1'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 添加好友按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('添加好友'),
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.blue),
                  onPressed: () {},
                ),
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
              children: const [
                _OverviewCard(icon: Icons.local_fire_department, label: '连胜天数', value: '54', color: Colors.orange),
                _OverviewCard(icon: Icons.flash_on, label: '总经验', value: '3179', color: Colors.amber),
                _OverviewCard(icon: Icons.emoji_events, label: '等级', value: '蓝宝石', color: Colors.blue),
                _OverviewCard(icon: Icons.flag, label: '德语分数', value: '8', color: Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
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

class _FontSettingSheet extends StatelessWidget {
  const _FontSettingSheet();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('字体设置', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 16),
          Text('这里可以放字体大小等设置项'),
        ],
      ),
    );
  }
} 