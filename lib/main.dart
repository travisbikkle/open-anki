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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    const DebugPage(),
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
            BottomNavigationBarItem(icon: Icon(Icons.bug_report), label: '调试'),
          ],
        ),
      ),
    );
  }
}
