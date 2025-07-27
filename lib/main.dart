import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/pages/home_page.dart';
import 'src/pages/import_page.dart';
import 'src/pages/notes_page.dart';
import 'src/pages/profile_page.dart';
import 'src/pages/debug_page.dart';
import 'package:open_anki/src/rust/frb_generated.dart';
import 'package:open_anki/src/rust/api/simple.manual.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'src/log_helper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'src/pages/splash_page.dart';

Future<void> writeTestHtml() async {
  final dir = await getApplicationDocumentsDirectory();
  final filePath = "${dir.path}/test.html";
  final file = File('${dir.path}/test.html');
  final file2 = File('${dir.path}/test2.html');
  await file2.writeAsString('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Test2</title>
  <style>body { background: #e0ffe0; color: #222; font-size: 28px; text-align: center; margin-top: 100px; }</style>
</head>
<body>
  Hello from iframe!<br>
  <span style="font-size:16px;">本页面为iframe内容。</span>
</body>
</html>
''');
  await file.writeAsString('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>WebView Local Test (iframe)</title>
  <style>
    body { background: #ffeedd; color: #222; font-size: 32px; text-align: center; margin-top: 100px; }
    iframe { width: 80vw; height: 300px; border: 2px solid #888; margin-top: 40px; }
  </style>
</head>
<body>
  Hello, WebView!<br>
  <span style="font-size:18px;">本页面用于测试WebView加载本地HTML文件的能力。</span>
  <span>$filePath</span>
  <br><br>
  <iframe src="file://${file2.path}"></iframe>
</body>
</html>
''');
  LogHelper.log('Test HTML written to: ${file.path}');
  LogHelper.log('Test2 HTML written to: ${file2.path}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogHelper.init();
  runApp(const SplashApp());
}

class SplashApp extends StatelessWidget {
  const SplashApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashPageWrapper(),
    );
  }
}

class SplashPageWrapper extends StatefulWidget {
  @override
  State<SplashPageWrapper> createState() => _SplashPageWrapperState();
}

class _SplashPageWrapperState extends State<SplashPageWrapper> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    await writeTestHtml();
    // 全局异常捕获
    FlutterError.onError = (FlutterErrorDetails details) async {
      FlutterError.presentError(details);
      LogHelper.log('FlutterError: ' + details.toString());
    };
    try {
      await RustLib.init();
      await initRustLog();
    } catch (e, st) {
      LogHelper.log('init error: $e\n$st');
    }
    rustLogStream.stream.listen((msg) {
      LogHelper.log('[RUST] $msg');
    });
    await Future.delayed(const Duration(milliseconds: 1200)); // 保证动画至少显示1.2秒
    setState(() {
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SplashPage();
    }
    return const ProviderScope(child: MyApp());
  }
}

Future<void> _writeCrashLog(String content) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/crash_log.txt');
    final now = DateTime.now().toIso8601String();
    await file.writeAsString('[$now] $content\n', mode: FileMode.append);
  } catch (e) {
    LogHelper.log('写入crash_log.txt失败: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale? newLocale) {
    final _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  Locale? _locale;
  final _pages = [
    const HomePage(),
    const ImportPage(),
    // const NotesPage(), // 移除笔记页
    const ProfilePage(),
  ];

  void setLocale(Locale? locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _selectedIndex.clamp(0, _pages.length - 1);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context)?.appTitle ?? 'Open Anki',
      home: Scaffold(
        body: _pages[safeIndex],
        bottomNavigationBar: Builder(
          builder: (context) => BottomNavigationBar(
            currentIndex: safeIndex,
            onTap: (idx) => setState(() => _selectedIndex = idx),
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.home), label: AppLocalizations.of(context)?.home ?? '首页'),
              BottomNavigationBarItem(icon: const Icon(Icons.menu_book), label: AppLocalizations.of(context)?.decks ?? '题库'),
              BottomNavigationBarItem(icon: const Icon(Icons.person), label: AppLocalizations.of(context)?.profile ?? '我'),
            ],
          ),
        ),
      ),
    );
  }
}
