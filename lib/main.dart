import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/pages/home_page.dart';
import 'src/pages/import_page.dart';
import 'src/pages/notes_page.dart';
import 'src/pages/profile_page.dart';
import 'package:open_anki/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
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
    return MaterialApp(
      home: Scaffold(
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (idx) => setState(() => _selectedIndex = idx),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: '导入'),
            BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '笔记'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: '我'),
          ],
        ),
      ),
    );
  }
}
