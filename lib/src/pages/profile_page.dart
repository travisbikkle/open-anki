import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  double _minFontSize = 18;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _minFontSize = prefs.getDouble('minFontSize') ?? 18;
      _loading = false;
    });
  }

  Future<void> _saveFontSize(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('minFontSize', value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('全局设置', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('最小字体大小', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 16),
                  Text('${_minFontSize.toInt()} px', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _minFontSize,
                min: 12,
                max: 128,
                divisions: 24,
                label: _minFontSize.toInt().toString(),
                onChanged: (v) {
                  setState(() => _minFontSize = v);
                  _saveFontSize(v);
                },
              ),
              const SizedBox(height: 32),
              const Text('（刷题页面的最小字体）', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
} 