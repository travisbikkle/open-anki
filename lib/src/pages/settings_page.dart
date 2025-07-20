import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db.dart';
import 'debug_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _minFontSize = 18;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _minFontSize = prefs.getDouble('minFontSize') ?? 18;
      _isLoading = false;
    });
  }

  Future<void> _saveFontSize(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('minFontSize', value);
    setState(() {
      _minFontSize = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeaf6ff),
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 字体设置卡片
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.text_fields, color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            const Text(
                              '字体设置',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text('最小字体大小'),
                            const Spacer(),
                            Text(
                              '${_minFontSize.toInt()}px',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _minFontSize,
                          min: 12,
                          max: 32,
                          divisions: 20,
                          activeColor: Colors.blue,
                          onChanged: _saveFontSize,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('12px', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('32px', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '预览效果',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '这是一段预览文字，当前最小字体大小为 ${_minFontSize.toInt()}px。',
                                style: TextStyle(
                                  fontSize: _minFontSize,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 其他设置卡片
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storage, color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            const Text(
                              '数据管理',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.delete_sweep),
                          title: const Text('清理缓存'),
                          subtitle: const Text('清理临时文件和缓存数据'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // TODO: 实现清理缓存功能
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('清理缓存功能开发中...')),
                            );
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.backup),
                          title: const Text('数据备份'),
                          subtitle: const Text('备份题库和学习进度'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // TODO: 实现数据备份功能
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('数据备份功能开发中...')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 开发者选项卡片
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.developer_mode, color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            const Text(
                              '开发者选项',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.bug_report),
                          title: const Text('调试工具'),
                          subtitle: const Text('查看数据库、文件系统等调试信息'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const DebugPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 关于卡片
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            const Text(
                              '关于',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.info),
                          title: const Text('版本信息'),
                          subtitle: const Text('Open Anki v1.0.0'),
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'Open Anki',
                              applicationVersion: '1.0.0',
                              applicationIcon: const FlutterLogo(size: 64),
                              children: const [
                                Text('一个开源的 Anki 卡片学习应用'),
                              ],
                            );
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.bug_report),
                          title: const Text('问题反馈'),
                          subtitle: const Text('报告问题或提出建议'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // TODO: 实现问题反馈功能
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('问题反馈功能开发中...')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 