import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../db.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:open_anki/src/rust/api/simple.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_html/flutter_html.dart';
import 'dart:convert'; // for base64Encode
import 'package:collection/collection.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sqflite/sqflite.dart'; // 新增导入
import 'package:open_anki/src/widgets/anki_template_renderer.dart';

const String kAutoMatchChoiceTemplate = '自动匹配-选择题模板';
const String kSqliteDBFileName = 'collection.sqlite';

class CardReviewPage extends ConsumerStatefulWidget {
  final String deckId;
  final Map<String, Uint8List>? mediaFiles;
  final Map<String, String>? mediaMap; // 文件名 -> 数字编号的映射
  const CardReviewPage({required this.deckId, this.mediaFiles, this.mediaMap, super.key});
  @override
  ConsumerState<CardReviewPage> createState() => _CardReviewPageState();
}

class _CardReviewPageState extends ConsumerState<CardReviewPage> {
  bool _loading = true;
  List<int> _noteIds = [];
  int _currentIndex = 0;
  String? _mediaDir;
  String? _sqlitePath;
  String? _deckVersion;
  NoteExt? _currentNote;
  NotetypeExt? _currentNotetype;
  List<FieldExt> _currentFields = [];
  late WebViewController _controller;
  // 新增交互状态
  int? _selectedIndex;
  bool _showAnswer = false;
  late WebViewController _stemController;
  late WebViewController _remarkController;
  int? _currentCardOrd;
  String? _currentQfmt;
  String? _currentAfmt;
  String? _currentCss;
  String? _currentFront;
  String? _currentBack;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));
    _stemController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));
    _remarkController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));
    _loadDeck();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<String?> _getDeckDir() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final allDecks = await AppDb.getAllDecks();
    final deck = allDecks.firstWhere(
      (d) => (d['md5'] ?? d['id'].toString()) == widget.deckId,
      orElse: () => <String, dynamic>{},
    );
    if (deck.isEmpty) return null;
    final md5 = deck['md5'] as String;
    return '${appDocDir.path}/anki_data/$md5';
  }

  Future<void> _loadDeck() async {
    setState(() { _loading = true; });
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final allDecks = await AppDb.getAllDecks();
      final deck = allDecks.firstWhere(
        (d) => (d['md5'] ?? d['id'].toString()) == widget.deckId,
        orElse: () => <String, dynamic>{},
      );
      if (deck.isEmpty) throw Exception('题库未找到');
      final md5 = deck['md5'] as String;
      final deckDir = '${appDocDir.path}/anki_data/$md5';
      final sqlitePath = '$deckDir/$kSqliteDBFileName';
      _sqlitePath = sqlitePath;
      _mediaDir = '$deckDir/unarchived_media';
      _deckVersion = deck['version'] as String? ?? 'anki2';
      // 只查ID列表
      final db = await openDatabase(sqlitePath);
      final idRows = await db.rawQuery('SELECT id FROM notes');
      _noteIds = idRows.map((e) => e['id'] as int).toList();
      await db.close();
      final progress = await AppDb.getProgress(deck['id'] as int);
      final idx = progress?['current_card_id'] ?? 0;
      _currentIndex = idx;
      await _loadCurrentCard();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载题库失败: $e')));
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _saveProgress(int idx) async {
    final allDecks = await AppDb.getAllDecks();
    final deck = allDecks.firstWhere(
      (d) => (d['md5'] ?? d['id'].toString()) == widget.deckId,
      orElse: () => <String, dynamic>{},
    );
    if (deck.isEmpty) return;
    final deckId = deck['id'] as int;
    await AppDb.saveProgress(deckId, idx);
    await AppDb.upsertRecentDeck(deckId);
    // 不再每次切题刷新 provider
    // ref.invalidate(allDecksProvider);
    // ref.invalidate(recentDecksProvider);
  }

  Future<void> _loadCurrentCard() async {
    if (_noteIds.isEmpty || _mediaDir == null || _currentIndex < 0 || _currentIndex >= _noteIds.length || _sqlitePath == null || _deckVersion == null) {
      debugPrint('[_loadCurrentCard] 条件不足，无法加载卡片');
      return;
    }
    setState(() {
      _selectedIndex = null;
      _showAnswer = false;
      _currentNote = null;
      _currentNotetype = null;
      _currentFields = [];
      _currentCardOrd = null;
      _currentQfmt = null;
      _currentAfmt = null;
      _currentCss = null;
      _currentFront = null;
      _currentBack = null;
      _showBack = false;
    });
    final noteId = _noteIds[_currentIndex];
    final result = await getDeckNote(sqlitePath: _sqlitePath!, noteId: noteId, version: _deckVersion!);
    setState(() {
      _currentNote = result.note;
      _currentNotetype = result.notetype;
      _currentFields = result.fields;
      _currentCardOrd = result.ord;
      _currentFront = result.front;
      _currentBack = result.back;
      _currentCss = result.css;
    });
    // 渲染
    if (_currentNotetype == null) {
      debugPrint('[_loadCurrentCard] _currentNotetype is null');
      return;
    }
    if (_currentNote == null) {
      debugPrint('[_loadCurrentCard] _currentNote is null');
      return;
    }
    final html = _composeCardFrontHtml(_currentNote!);
    _controller.loadHtmlString(html, baseUrl: _mediaDir != null ? 'file://${_mediaDir!}/' : null);
  }

  String _composeCardFrontHtml(NoteExt note) {
    final fieldsForType = List<FieldExt>.from(_currentFields)..sort((a, b) => a.ord.compareTo(b.ord));
    final fieldMap = <String, String>{};
    for (int i = 0; i < fieldsForType.length && i < note.flds.length; i++) {
      fieldMap[fieldsForType[i].name] = note.flds[i];
    }
    String front = '', back = '', css = '';
    front = _currentFront ?? '';
    back = _currentBack ?? '';
    css = _currentCss ?? '';
    final renderer = AnkiTemplateRenderer(
      front: front,
      back: back,
      css: css,
      fieldMap: fieldMap,
      js: null,
    );
    return renderer.renderFront();
  }

  String _composeCardBackHtml(NoteExt note) {
    final fieldsForType = List<FieldExt>.from(_currentFields)..sort((a, b) => a.ord.compareTo(b.ord));
    final fieldMap = <String, String>{};
    for (int i = 0; i < fieldsForType.length && i < note.flds.length; i++) {
      fieldMap[fieldsForType[i].name] = note.flds[i];
    }
    String front = '', back = '', css = '';
    front = _currentFront ?? '';
    back = _currentBack ?? '';
    css = _currentCss ?? '';
    final renderer = AnkiTemplateRenderer(
      front: front,
      back: back,
      css: css,
      fieldMap: fieldMap,
      js: null,
    );
    return renderer.renderBack(renderer.renderFront());
  }

  String _wrapHtml(String content) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: system-ui, sans-serif; font-size: 50px; padding: 8; margin: 0; }
    .stem { font-size: 20px; font-weight: bold; line-height: 2; }
  </style>
</head>
<body>
$content
</body>
</html>
''';
  }

  void _nextCard() {
    if (_noteIds.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _noteIds.length;
    });
    _saveProgress(_currentIndex);
    _loadCurrentCard();
  }

  void _prevCard() {
    if (_noteIds.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _noteIds.length) % _noteIds.length;
    });
    _saveProgress(_currentIndex);
    _loadCurrentCard();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[build] _loading=$_loading, _noteIds=${_noteIds.length}, _currentIndex=$_currentIndex, _currentNote=${_currentNote != null}, _currentNotetype=${_currentNotetype != null}');
    if (_loading) {
      debugPrint('[build] 正在加载...');
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_noteIds.isEmpty) {
      debugPrint('[build] _noteIds 为空');
      return Scaffold(
        appBar: AppBar(title: const Text('刷卡')),
        body: const Center(child: Text('无卡片')),
      );
    }
    if (_currentNote == null) {
      debugPrint('[build] _currentNote 为空');
      return Scaffold(
        appBar: AppBar(title: const Text('刷卡')),
        body: const Center(child: Text('卡片加载失败')),
      );
    }
    final note = _currentNote;
    final notetype = _currentNotetype;
    debugPrint('[build] 渲染卡片: note.id=${note?.id}, notetype=${notetype?.name}');
    if (notetype != null && notetype.name == kAutoMatchChoiceTemplate) {
      debugPrint('[build] 使用自定义模板渲染');
      final html = _showBack
          ? _composeCardBackHtml(note!)
          : _composeCardFrontHtml(note!);
      debugPrint('[build] 渲染HTML长度: ${html.length}');
      return Scaffold(
        appBar: AppBar(
          title: Text('刷卡 ( ${_currentIndex + 1}/${_noteIds.length})'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Container(
              color: Colors.black12,
              padding: const EdgeInsets.all(8),
              child: Text(
                'mediaDir=${_mediaDir ?? "null"}\nnote.mid: ${note.mid}\nnotetype: ${notetype?.name}\nfields: ${_currentFields.map((f) => f.name).join(", ")}',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
            Expanded(child: WebViewWidget(key: ValueKey(_currentIndex * 2 + (_showBack ? 1 : 0)), controller: _controller)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.navigate_before),
                    label: const Text('上一题'),
                    onPressed: _prevCard,
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showBack = !_showBack;
                        if (_showBack) {
                          _controller.loadHtmlString(_composeCardBackHtml(note!), baseUrl: _mediaDir != null ? 'file://${_mediaDir!}/' : null);
                        } else {
                          _controller.loadHtmlString(_composeCardFrontHtml(note!), baseUrl: _mediaDir != null ? 'file://${_mediaDir!}/' : null);
                        }
                      });
                    },
                    child: Text(_showBack ? '返回正面' : '显示答案'),
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.navigate_next),
                    label: const Text('下一题'),
                    onPressed: _nextCard,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    debugPrint('[build] 使用自定义模板渲染');
    final html = _showBack
        ? _composeCardBackHtml(note!)
        : _composeCardFrontHtml(note!);
    debugPrint('[build] 渲染HTML长度: ${html.length}');
    return Scaffold(
      appBar: AppBar(
        title: Text('刷卡 ( ${_currentIndex + 1}/${_noteIds.length})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.all(8),
            child: Text(
              'mediaDir=${_mediaDir ?? "null"}\nnote.mid: ${note.mid}\nnotetype: ${notetype?.name}\nfields: ${_currentFields.map((f) => f.name).join(", ")}',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
          Expanded(child: WebViewWidget(key: ValueKey(_currentIndex * 2 + (_showBack ? 1 : 0)), controller: _controller)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.navigate_before),
                  label: const Text('上一题'),
                  onPressed: _prevCard,
                ),
                const SizedBox(width: 24),
                ElevatedButton(
                  onPressed: !_showBack ? () {
                    setState(() {
                      _showBack = true;
                      _controller.loadHtmlString(_composeCardBackHtml(note!), baseUrl: _mediaDir != null ? 'file://${_mediaDir!}/' : null);
                    });
                  } : null,
                  child: const Text('显示答案'),
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.navigate_next),
                  label: const Text('下一题'),
                  onPressed: _nextCard,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 