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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../main.dart';
import '../constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _minFontSize = 22;
  bool _isLoading = true;
  Locale? _selectedLocale;

  static const supportedLocales = [
    Locale('system', ''),
    Locale('en'),
    Locale('zh'),
    Locale('de'),
    Locale('ru'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLocale();
  }

  String _schedulingAlgorithm = 'fsrs';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _minFontSize = prefs.getDouble('minFontSize') ?? 22;
      _schedulingAlgorithm = prefs.getString('schedulingAlgorithm') ?? 'fsrs';
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

  Future<void> _saveSchedulingAlgorithm(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('schedulingAlgorithm', value);
    setState(() {
      _schedulingAlgorithm = value;
    });
  }

  Future<void> sendFeedbackEmail(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final log = await LogHelper.getRecentLog();
    final subject = Uri.encodeComponent(AppLocalizations.of(context)!.feedbackMailSubject(kAppName));
    final body = Uri.encodeComponent(
      AppLocalizations.of(context)!.feedbackMailBody(
        info.version,
        info.buildNumber,
        info.packageName,
        Platform.operatingSystem,
        Platform.operatingSystemVersion,
        log,
      ),
    );
    final email = kSupportEmail;
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
    final body = AppLocalizations.of(context)!.feedbackMailBodyWithAttachment(
      info.version,
      info.buildNumber,
      info.packageName,
      Platform.operatingSystem,
      Platform.operatingSystemVersion,
    );
    final email = Email(
      body: body,
      subject: AppLocalizations.of(context)!.feedbackMailSubject(kAppName),
      recipients: [kSupportEmail],
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

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('locale');
    setState(() {
      _selectedLocale = code == null || code == 'system' ? null : Locale(code);
    });
  }

  Future<void> _saveLocale(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null || code == 'system') {
      await prefs.remove('locale');
      setState(() { _selectedLocale = null; });
    } else {
      await prefs.setString('locale', code);
      setState(() { _selectedLocale = Locale(code); });
    }
    // 通知全局刷新
    MyApp.setLocale(context, _selectedLocale);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeaf6ff),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.settings ?? 'Settings'),
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
                            Text(
                              AppLocalizations.of(context)!.fontSize,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(AppLocalizations.of(context)!.minFontSize),
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
                          children: [
                            Text('12px', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('128px', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                              Text(
                                'Preview', // TODO: Add to ARB
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(context)!.fontSize + ': ${_minFontSize.toInt()}px',
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
                // 调度算法设置卡片
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
                            Icon(Icons.schedule, color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)!.schedulingAlgorithm,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(AppLocalizations.of(context)!.schedulingAlgorithm),
                            const Spacer(),
                            DropdownButton<String>(
                              value: _schedulingAlgorithm,
                              items: const [
                                DropdownMenuItem(
                                  value: 'fsrs',
                                  child: Text('FSRS (AI)'), // TODO: Add to ARB
                                ),
                                DropdownMenuItem(
                                  value: 'simple',
                                  child: Text('Simple'), // TODO: Add to ARB
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _saveSchedulingAlgorithm(value);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _schedulingAlgorithm == 'fsrs' ? 'FSRS (AI)' : 'Simple', // TODO: Add to ARB
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _schedulingAlgorithm == 'fsrs' 
                                  ? AppLocalizations.of(context)!.fsrsDesc
                                  : AppLocalizations.of(context)!.simpleDesc,
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 语言切换卡片
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
                            Icon(Icons.language, color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context)!.language,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        DropdownButton<Locale?>(
                          value: _selectedLocale ?? const Locale('system', ''),
                          items: [
                            DropdownMenuItem(
                              value: const Locale('system', ''),
                              child: Text(AppLocalizations.of(context)!.systemDefault),
                            ),
                            DropdownMenuItem(
                              value: const Locale('en'),
                              child: Text(AppLocalizations.of(context)!.english),
                            ),
                            DropdownMenuItem(
                              value: const Locale('zh'),
                              child: Text(AppLocalizations.of(context)!.chinese),
                            ),
                            DropdownMenuItem(
                              value: const Locale('de'),
                              child: Text(AppLocalizations.of(context)!.german),
                            ),
                            DropdownMenuItem(
                              value: const Locale('ru'),
                              child: Text(AppLocalizations.of(context)!.russian),
                            ),
                            DropdownMenuItem(
                              value: const Locale('fr'),
                              child: Text(AppLocalizations.of(context)!.french),
                            ),
                            DropdownMenuItem(
                              value: const Locale('ja'),
                              child: Text(AppLocalizations.of(context)!.japanese),
                            ),
                            DropdownMenuItem(
                              value: const Locale('ko'),
                              child: Text(AppLocalizations.of(context)!.korean),
                            ),
                          ],
                          onChanged: (locale) {
                            _saveLocale(locale?.languageCode == 'system' ? null : locale?.languageCode);
                          },
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
                              Text(
                                'Developer Options', // TODO: Add to ARB
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.bug_report),
                            title: Text(AppLocalizations.of(context)!.debugTool),
                            subtitle: Text(AppLocalizations.of(context)!.debugToolDesc),
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
                            Text(
                              AppLocalizations.of(context)!.about,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.info),
                          title: Text(AppLocalizations.of(context)!.versionInfo),
                          subtitle: Text('$kAppName v1.0.0'),
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: kAppName,
                              applicationVersion: '1.0.0',
                              applicationIcon: ClipOval(
                                child: SvgPicture.asset(
                                  'assets/icon.svg',
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              children: [
                                 Text('An open-source Anki flashcard app'), // TODO: Add to ARB
                              ],
                            );
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.article_outlined),
                          title: Text(AppLocalizations.of(context)!.eula),
                          onTap: () async {
                            final url = Uri.parse('https://anki.eusoftbank.com/en/eula');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: Text(AppLocalizations.of(context)!.privacyPolicy),
                          onTap: () async {
                            final url = Uri.parse('https://anki.eusoftbank.com/en/policy');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.bug_report),
                          title: Text(AppLocalizations.of(context)!.feedback),
                          subtitle: Text(AppLocalizations.of(context)!.feedbackDesc),
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