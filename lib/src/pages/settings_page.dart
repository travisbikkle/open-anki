import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db.dart';
import 'debug_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import '../log_helper.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

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

  Future<void> sendFeedbackEmail(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final log = await LogHelper.getRecentLog();
    final subject = Uri.encodeComponent('Open Anki 问题反馈');
    final body = Uri.encodeComponent(
      '请详细描述您的问题，并可在邮件中添加截图。\n\n'
      '---\n'
      'App版本: ${info.version} (${info.buildNumber})\n'
      '包名: ${info.packageName}\n'
      '平台: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n'
      '最近日志(部分):\n$log\n'
    );
    final email = 'support@example.com'; // TODO: 替换为你的支持邮箱
    final uri = 'mailto:$email?subject=$subject&body=$body';
    if (await canLaunch(uri)) {
      await launch(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开邮件客户端，请手动发送反馈邮件。')),
      );
    }
  }

  Future<String> zipLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final logFile = File('${dir.path}/open_anki.log');
    final zipPath = '${dir.path}/open_anki_log.zip';
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    if (await logFile.exists()) {
      encoder.addFile(logFile);
    }
    encoder.close();
    return zipPath;
  }

  Future<void> sendFeedbackWithAttachment(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final zipPath = await zipLogFile();
    final body =
        '请详细描述您的问题，并可在邮件中添加截图。\n\n---\nApp版本: ${info.version} (${info.buildNumber})\n包名: ${info.packageName}\n平台: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n日志见附件。';
    final email = Email(
      body: body,
      subject: 'Open Anki 问题反馈',
      recipients: ['support@eusoftbank.com'],
      attachmentPaths: [zipPath],
      isHTML: false,
    );
    try {
      await FlutterEmailSender.send(email);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开邮件客户端: $e')),
      );
    }
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
                          max: 128,
                          divisions: 100,
                          activeColor: Colors.blue,
                          onChanged: _saveFontSize,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('12px', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('128px', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                // 开发者选项卡片
                if (!kReleaseMode)
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
                              applicationIcon: ClipOval(
                                child: SvgPicture.asset(
                                  'assets/icon.svg',
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
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
                          onTap: () => sendFeedbackWithAttachment(context),
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