import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../db.dart';
import '../model.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter/webview_flutter.dart';

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
  List<DeckInfo> _dbDecks = [];
  bool _showDbDecks = false;
  String? _selectedDebugAction;
  final List<Map<String, dynamic>> _debugActions = [
    {
      'label': '显示所有Deck记录',
      'action': '_showAllDecks',
    },
    {
      'label': '显示所有卡片调度状态',
      'action': '_showAllScheduling',
    },
    {
      'label': '测试调度参数保存',
      'action': '_testScheduling',
    },
    {
      'label': '跳转到底部',
      'action': '_scrollToBottom',
    },
    {
      'label': '测试本地HTML加载',
      'action': '_testWebView',
    },
    {
      'label': '浏览题库文件树',
      'action': '_showFileTree',
    },
  ];
  List<Map<String, dynamic>> _allDeckRows = [];
  List<Map<String, dynamic>> _allSchedulingRows = [];
  bool _showAllDeckCards = false;
  bool _showFileTree = false;
  bool _showScheduling = false;

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

  Future<void> _showAllDecks() async {
    final dbClient = await AppDb.db;
    final rows = await dbClient.rawQuery('SELECT md5, apkg_path, version, user_deck_name FROM decks');
    setState(() {
      _allDeckRows = rows;
      _showAllDeckCards = true;
    });
  }

  Future<void> _testScheduling() async {
    try {
      // 测试1: 保存调度参数
      final testCardId = 99999;
      final testScheduling = CardScheduling(
        cardId: testCardId,
        stability: 3.0,
        difficulty: 4.5,
        due: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      
      await AppDb.upsertCardScheduling(testScheduling);
      
      // 测试2: 读取调度参数
      final retrievedScheduling = await AppDb.getCardScheduling(testCardId);
      
      // 测试3: 更新调度参数
      final updatedScheduling = CardScheduling(
        cardId: testCardId,
        stability: 4.2,
        difficulty: 3.8,
        due: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400, // 1天后
      );
      
      await AppDb.upsertCardScheduling(updatedScheduling);
      
      // 测试4: 验证更新
      final finalScheduling = await AppDb.getCardScheduling(testCardId);
      
      // 显示测试结果
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('调度参数测试结果'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('初始保存: ${retrievedScheduling != null ? "成功" : "失败"}'),
              if (retrievedScheduling != null) ...[
                Text('初始稳定性: ${retrievedScheduling.stability}'),
                Text('初始难度: ${retrievedScheduling.difficulty}'),
              ],
              const SizedBox(height: 8),
              Text('更新保存: ${finalScheduling != null ? "成功" : "失败"}'),
              if (finalScheduling != null) ...[
                Text('更新后稳定性: ${finalScheduling.stability}'),
                Text('更新后难度: ${finalScheduling.difficulty}'),
                Text('下次复习: ${finalScheduling.due}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('测试失败'),
          content: Text('错误: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showAllScheduling() async {
    setState(() { _showScheduling = true; });
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final allScheduling = await AppDb.getAllCardScheduling();
      setState(() {
        _allSchedulingRows = allScheduling.map((s) {
          final dueIn = s.due - now;
          String dueText;
          if (dueIn < 0) {
            dueText = '已过期 ${(-dueIn / 3600).round()} 小时';
          } else if (dueIn < 3600) {
            dueText = '${(dueIn / 60).round()} 分钟后';
          } else if (dueIn < 86400) {
            dueText = '${(dueIn / 3600).round()} 小时后';
          } else {
            dueText = '${(dueIn / 86400).round()} 天后';
          }
          return {
            'card_id': s.cardId,
            'stability': s.stability.toStringAsFixed(1),
            'difficulty': s.difficulty.toStringAsFixed(1),
            'due': dueText,
          };
        }).toList();
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    }
  }

  void _scrollToBottom() {
    final scrollController = PrimaryScrollController.of(context);
    scrollController?.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }
  void _testWebView() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TestWebViewPage()));
  }

  void _showFileTreeAction() {
    setState(() {
      _showFileTree = true;
      _showAllDeckCards = false;
      _showDbDecks = false;
    });
  }

  Widget _buildDeckDirView(Directory deckDir) {
    return FutureBuilder<List<FileSystemEntity>>(
      future: deckDir.list().toList(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(title: Text('加载中...'));
        }
        final entities = snapshot.data!;
        // 1. 只保留 collection.sqlite、collection.anki2、unarchived_media/media 文件夹和其他文件
        final collectionFiles = entities.where((e) => e is File && (e.path.endsWith('collection.sqlite') || e.path.endsWith('collection.anki2'))).toList();
        final mediaDirs = entities.where((e) => e is Directory && (p.basename(e.path) == 'unarchived_media' )).toList();
        final otherDirs = entities.where((e) => e is Directory && !(p.basename(e.path) == 'unarchived_media')).toList();
        final otherFiles = entities.where((e) => e is File && !(e.path.endsWith('collection.sqlite') || e.path.endsWith('collection.anki2'))).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // collection.sqlite/anki2优先
            for (final f in collectionFiles)
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(p.basename(f.path)),
                subtitle: Text(f.path, style: const TextStyle(fontSize: 12)),
                contentPadding: const EdgeInsets.only(left: 16),
              ),
            // media文件夹优先
            for (final mediaDir in mediaDirs)
              FutureBuilder<List<FileSystemEntity>>(
                future: Directory(mediaDir.path).list().toList(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return ListTile(title: Text('${mediaDir.path.split('/').last}/ (加载中...)'), leading: const Icon(Icons.folder), contentPadding: const EdgeInsets.only(left: 16));
                  }
                  final files = snap.data!;
                  // 纯数字文件在后，文件夹在前
                  final subDirs = files.where((e) => e is Directory).toList();
                  final specialFiles = files.where((e) => e is File && (p.basename(e.path) == 'unarchived_media' || p.basename(e.path) == 'collection.sqlite' || p.basename(e.path) == 'collection.anki2')).toList();
                  final normalFiles = files.where((e) => e is File && !RegExp(r'^\d+ ?$').hasMatch(p.basename(e.path)) && !specialFiles.contains(e)).toList();
                  final digitFiles = files.where((e) => e is File && RegExp(r'^\d+$').hasMatch(p.basename(e.path))).toList();
                  return ExpansionTile(
                    leading: const Icon(Icons.folder),
                    title: Text('unarchived_media/'),
                    children: [
                      for (final d in subDirs)
                        ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(p.basename(d.path) + '/'),
                          subtitle: Text(d.path, style: const TextStyle(fontSize: 12)),
                          contentPadding: const EdgeInsets.only(left: 32),
                        ),
                      for (final f in specialFiles)
                        ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(p.basename(f.path)),
                          subtitle: Text(f.path, style: const TextStyle(fontSize: 12)),
                          contentPadding: const EdgeInsets.only(left: 32),
                        ),
                      for (final f in normalFiles)
                        ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(p.basename(f.path)),
                          subtitle: Text(f.path, style: const TextStyle(fontSize: 12)),
                          contentPadding: const EdgeInsets.only(left: 32),
                        ),
                      for (final f in digitFiles)
                        ListTile(
                          leading: const Icon(Icons.confirmation_number),
                          title: Text(p.basename(f.path)),
                          subtitle: Text(f.path, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                          contentPadding: const EdgeInsets.only(left: 32),
                        ),
                    ],
                  );
                },
              ),
            // 其他文件夹
            for (final d in otherDirs)
              ListTile(
                leading: const Icon(Icons.folder),
                title: Text(p.basename(d.path) + '/'),
                subtitle: Text(d.path, style: const TextStyle(fontSize: 12)),
                contentPadding: const EdgeInsets.only(left: 16),
              ),
            // 其他文件
            for (final f in otherFiles)
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(p.basename(f.path)),
                subtitle: Text(f.path, style: const TextStyle(fontSize: 12)),
                contentPadding: const EdgeInsets.only(left: 16),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showScheduling && _allSchedulingRows.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('卡片调度状态')),
        body: ListView.builder(
          itemCount: _allSchedulingRows.length,
          itemBuilder: (context, idx) {
            final row = _allSchedulingRows[idx];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('卡片ID: ${row['card_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('稳定性: ${row['stability']}'),
                    Text('难度: ${row['difficulty']}'),
                    Text('下次复习: ${row['due']}'),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('调试-题库文件树浏览')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedDebugAction,
                  hint: const Text('选择调试操作'),
                  items: _debugActions.map((item) => DropdownMenuItem<String>(
                    value: item['action'],
                    child: Text(item['label']),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDebugAction = val;
                      _showAllDeckCards = false;
                      _showFileTree = false;
                      _showDbDecks = false;
                    });
                    if (val == '_showAllDecks') {
                      setState(() { _showAllDeckCards = true; });
                      _showAllDecks();
                    }
                    if (val == '_showAllScheduling') {
                      _showAllScheduling();
                    }
                    if (val == '_testScheduling') {
                      _testScheduling();
                    }
                    if (val == '_scrollToBottom') _scrollToBottom();
                    if (val == '_testWebView') _testWebView();
                    if (val == '_showFileTree') {
                      setState(() { _showFileTree = true; });
                    }
                  },
                ),
              ],
            ),
          ),
          if (_showAllDeckCards)
            Expanded(
              child: ListView.builder(
                itemCount: _allDeckRows.length,
                itemBuilder: (context, idx) {
                  final row = _allDeckRows[idx];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (row['user_deck_name'] != null)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('名称: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      row['user_deck_name'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (row['user_deck_name'] != null) const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('md5: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  row['md5'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('apkg_path: '),
                              Expanded(
                                child: Text(
                                  row['apkg_path'] ?? '',
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          if (row['version'] != null)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('version: '),
                                Expanded(
                                  child: Text(
                                    row['version'] ?? '',
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_showFileTree)
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
                                for (final entity in _rootEntities)
                                  if (entity is Directory)
                                    ExpansionTile(
                                      leading: const Icon(Icons.folder),
                                      title: Text(entity.path.split('/').last + '/'),
                                      children: [
                                        _buildDeckDirView(entity),
                                      ],
                                    ),
                              ],
                            ),
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
          if (!_showDbDecks && !_showAllDeckCards && !_showFileTree)
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
                                // 只展示每个deck目录下的collection.sqlite和media
                                for (final entity in _rootEntities)
                                  if (entity is Directory)
                                    ExpansionTile(
                                      leading: const Icon(Icons.folder),
                                      title: Text(entity.path.split('/').last + '/'),
                                      children: [
                                        _buildDeckDirView(entity),
                                      ],
                                    ),
                              ],
                            ),
            ),
        ],
      ),
    );
  }
}

class TestWebViewPage extends StatefulWidget {
  const TestWebViewPage({super.key});
  @override
  State<TestWebViewPage> createState() => _TestWebViewPageState();
}

class _TestWebViewPageState extends State<TestWebViewPage> {
  String? _fileUrl;

  @override
  void initState() {
    super.initState();
    _loadFileUrl();
  }

  Future<void> _loadFileUrl() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/test.html');
    setState(() {
      _fileUrl = 'file://${file.path}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test WebView Local HTML')),
      body: _fileUrl == null
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: WebViewController()..loadRequest(Uri.parse(_fileUrl!))),
    );
  }
} 