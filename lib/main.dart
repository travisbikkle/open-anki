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
  print('Test HTML written to: ${file.path}');
  print('Test2 HTML written to: ${file2.path}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await writeTestHtml();
  try {
    await RustLib.init();
    await initRustLog();
  } catch (e, st) {
    print('init error: $e\n$st');
  }
  rustLogStream.stream.listen((msg) {
    print('[RUST] $msg');
  });
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  final _pages = [
    const HomePage(),
    const ImportPage(),
    const NotesPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final safeIndex = _selectedIndex.clamp(0, _pages.length - 1);
    return MaterialApp(
      home: Scaffold(
        body: _pages[safeIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (idx) => setState(() => _selectedIndex = idx),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '题库'),
            BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '笔记'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: '我'),
          ],
        ),
      ),
    );
  }
}
