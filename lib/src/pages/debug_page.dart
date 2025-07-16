import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../db.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});
  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  Directory? _ankiDataDir;
  bool _loading = true;
  String? _error;
  List<FileSystemEntity> _rootEntities = [];
  List<Map<String, dynamic>> _dbDecks = [];
  bool _showDbDecks = false;

  @override
  void initState() {
    super.initState();
    _loadRoot();
  }

  Future<void> _loadRoot() async {
    setState(() { _loading = true; _error = null; });
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final ankiDataDir = Directory('${appDocDir.path}/anki_data');
      if (!await ankiDataDir.exists()) {
        setState(() { _ankiDataDir = null; _rootEntities = []; _loading = false; });
        return;
      }
      final entities = await ankiDataDir.list().toList();
      setState(() {
        _ankiDataDir = ankiDataDir;
        _rootEntities = entities;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadDbDecks() async {
    final decks = await AppDb.getAllDecks();
    setState(() {
      _dbDecks = decks;
      _showDbDecks = true;
    });
  }

  Widget _buildTree(FileSystemEntity entity) {
    if (entity is Directory) {
      return FutureBuilder<List<FileSystemEntity>>(
        future: entity.list().toList(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return ListTile(title: Text(entity.path.split('/').last + '/'), leading: const Icon(Icons.folder));
          }
          final children = snapshot.data!;
          // 过滤只显示 collection.sqlite 文件
          final sqliteFiles = children.where((e) => 
            e is File && e.path.endsWith('collection.sqlite')
          ).toList();
          if (sqliteFiles.isEmpty) {
            return ListTile(title: Text(entity.path.split('/').last + '/'), leading: const Icon(Icons.folder));
          }
          return ExpansionTile(
            leading: const Icon(Icons.folder),
            title: Text(entity.path.split('/').last + '/'),
            children: sqliteFiles.map((e) => ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.green),
              title: Text('collection.sqlite'),
              subtitle: Text(e.path, style: const TextStyle(fontSize: 12)),
            )).toList(),
          );
        },
      );
    } else {
      // 只显示 collection.sqlite 文件
      if (entity.path.endsWith('collection.sqlite')) {
        return ListTile(
          leading: const Icon(Icons.insert_drive_file, color: Colors.green),
          title: Text('collection.sqlite'),
          subtitle: Text(entity.path, style: const TextStyle(fontSize: 12)),
        );
      }
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('调试-题库文件树浏览')),
      body: Column(
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: _loadDbDecks,
                child: const Text('显示题库索引(AppDb.getAllDecks)'),
              ),
            ],
          ),
          if (_showDbDecks)
            Expanded(
              child: ListView(
                children: [
                  for (final deck in _dbDecks)
                    ListTile(title: Text(deck.toString())),
                ],
              ),
            ),
          if (!_showDbDecks)
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('错误: $_error'))
                      : _ankiDataDir == null
                          ? const Center(child: Text('anki_data 目录不存在'))
                          : ListView(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.sd_storage),
                                  title: Text(_ankiDataDir!.path),
                                ),
                                ..._rootEntities.map(_buildTree),
                              ],
                            ),
            ),
        ],
      ),
    );
  }
} 