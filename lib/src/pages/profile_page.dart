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

class _ProfilePageState extends ConsumerState<ProfilePage> with SingleTickerProviderStateMixin {
  late Future<List<dynamic>> _profileFuture = _makeProfileFuture();
  static Future<List<dynamic>> _makeProfileFuture() => Future.wait([
    AppDb.getConsecutiveStudyDays(),
    AppDb.getTodayStudyCount(),
    AppDb.getTotalStudyDays(),
    AppDb.getFirstStudyDate(),
    AppDb.getUserName(),
  ]);

  late AnimationController _nickAnimController;
  late Animation<double> _nickAnim;
  bool _hasCustomName = false;
  bool _showPencil = true;
  bool _editingName = false;
  final GlobalKey _nickKey = GlobalKey();
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    _refreshProfile();
    _nickAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _nickAnim = Tween(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(parent: _nickAnimController, curve: Curves.easeInOut),
    );
    _playNickAnim();
    _editFocusNode.addListener(() {
      if (!_editFocusNode.hasFocus && _editingName) {
        _submitName();
      }
    });
  }

  void _refreshProfile() {
    _profileFuture = _makeProfileFuture();
  }

  Future<void> _checkCustomName() async {
    final name = await AppDb.getUserName();
    setState(() { _hasCustomName = false; _showPencil = true; });
    // 跳动2次
    for (int i = 0; i < 2; i++) {
      await _nickAnimController.forward();
      await Future.delayed(const Duration(milliseconds: 120));
      _nickAnimController.reverse();
      await Future.delayed(const Duration(milliseconds: 120));
    }
    setState(() { _showPencil = false; });
  }

  Future<void> _playNickAnim() async {
    for (int i = 0; i < 2; i++) {
      await _nickAnimController.forward();
      await _nickAnimController.reverse();
    }
  }

  void _submitName() async {
    final newName = _editController.text.trim();
    if (newName.isNotEmpty && newName != _currentUserName) {
      await AppDb.setUserName(newName);
      _refreshProfile();
    }
    setState(() { _editingName = false; });
  }

  @override
  void dispose() {
    _nickAnimController.dispose();
    super.dispose();
  }

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
    return FutureBuilder<List<dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final consecutiveDays = snapshot.data != null ? snapshot.data![0] as int : 0;
        final todayCount = snapshot.data != null ? snapshot.data![1] as int : 0;
        final totalStudyDays = snapshot.data != null ? snapshot.data![2] as int : 0;
        final firstStudyDate = snapshot.data != null ? snapshot.data![3] as DateTime? : null;
        final userName = snapshot.data != null ? snapshot.data![4] as String : 'Player';
        _currentUserName = userName;
        String joinText = '';
        if (firstStudyDate != null) {
          joinText = '${firstStudyDate.year}年${firstStudyDate.month}月加入';
        }
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
                    GestureDetector(
                      onTap: () async {
                        setState(() { _editingName = true; });
                      },
                      child: SizedBox(
                        height: 36,
                        width: 260,
                        child: Center(
                          child: _editingName
                              ? SizedBox(
                                  width: 160,
                                  child: Builder(
                                    builder: (context) {
                                      _editController.text = userName;
                                      return TextField(
                                        focusNode: _editFocusNode,
                                        controller: _editController,
                                        autofocus: true,
                                        maxLength: 20,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          counterText: '',
                                          isDense: true,
                                          hintText: '请输入昵称',
                                        ),
                                        onSubmitted: (_) => _submitName(),
                                      );
                                    },
                                  ),
                                )
                              : AnimatedBuilder(
                                  animation: _nickAnim,
                                  builder: (context, child) {
                                    final offsetY = _nickAnim.value * 8;
                                    final scale = 1.0 + (_nickAnim.value.abs() * 0.10);
                                    return Transform.translate(
                                      offset: Offset(0, offsetY),
                                      child: Transform.scale(
                                        scale: scale,
                                        child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    if (firstStudyDate != null)
                      Text(joinText, style: TextStyle(color: Colors.grey, fontSize: 14)),
                    // 不再显示“昵称其实可以点哦😉”等文字提示
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
                    _StatCard(icon: Icons.psychology, label: '学习天数', value: totalStudyDays.toString()),
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