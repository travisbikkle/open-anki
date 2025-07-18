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
  List<NoteExt> _notes = [];
  List<NotetypeExt> _cardNotetypes = [];
  List<FieldExt> _fields = [];
  int _currentIndex = 0;
  String? _mediaDir;
  late WebViewController _controller;
  // 新增交互状态
  int? _selectedIndex;
  bool _showAnswer = false;
  late WebViewController _stemController;
  late WebViewController _remarkController;

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
      final result = await getDeckNotes(sqlitePath: sqlitePath);
      debugPrint('【_loadDeck】result.notetypes: ${result.notetypes}');
      final newMediaDir = '$deckDir/unarchived_media';
      setState(() {
        _notes = result.notes.cast<NoteExt>();
        _cardNotetypes = result.notetypes.cast<NotetypeExt>();
        _fields = result.fields.cast<FieldExt>();
        if (_mediaDir != newMediaDir) {
          _mediaDir = newMediaDir;
          _controller = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0x00000000));
          _stemController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0x00000000));
          _remarkController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0x00000000));
        }
      });
      final progress = await AppDb.getProgress(deck['id'] as int);
      final idx = progress?['current_card_id'] ?? 0;
      _currentIndex = idx;
      _loadCurrentCard();
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
    ref.invalidate(allDecksProvider);
    ref.invalidate(recentDecksProvider);
  }

  void _loadCurrentCard() {
    if (_notes.isEmpty || _mediaDir == null || _currentIndex < 0 || _currentIndex >= _notes.length) return;
    setState(() {
      _selectedIndex = null;
      _showAnswer = false;
    });
    final note = _notes[_currentIndex];
    final notetype = _cardNotetypes.firstWhereOrNull((n) => n.id == note.mid);
    if (notetype != null && notetype.name == kAutoMatchChoiceTemplate) {
      final fieldsForType = _fields.where((f) => f.notetypeId == note.mid).toList()..sort((a, b) => a.ord.compareTo(b.ord));
      final fieldMap = <String, String>{};
      for (int i = 0; i < fieldsForType.length && i < note.flds.length; i++) {
        fieldMap[fieldsForType[i].name] = note.flds[i];
      }
      final stem = fieldMap['Question'] ?? fieldMap.values.firstOrNull ?? '';
      final remark = fieldMap['remark'] ?? fieldMap['Remark'] ?? '';
      _stemController.loadHtmlString(_wrapHtml(stem), baseUrl: 'file://${_mediaDir!}/');
      _remarkController.loadHtmlString(_wrapHtml(remark), baseUrl: 'file://${_mediaDir!}/');
    } else {
      final html = _composeCardHtml(note);
      _controller.loadHtmlString(html, baseUrl: 'file://${_mediaDir!}/');
    }
  }

  String _composeCardHtml(NoteExt note) {
    NotetypeExt? notetype;
    try {
      notetype = _cardNotetypes.firstWhere(
        (n) => n.id == note.mid,
        orElse: () => NotetypeExt(id: -1, name: '', config: ''),
      );
    } catch (e) {
      notetype = null;
    }
    // 获取当前 notetype 的所有字段，按 ord 排序
    final fieldsForType = _fields
        .where((f) => f.notetypeId == note.mid)
        .toList()
      ..sort((a, b) => a.ord.compareTo(b.ord));
    // 组装字段名与内容映射
    final fieldMap = <String, String>{};
    for (int i = 0; i < fieldsForType.length && i < note.flds.length; i++) {
      fieldMap[fieldsForType[i].name] = note.flds[i];
    }
    // 自动匹配-选择题模板专用渲染（必须保留！）
    if (notetype != null && notetype.name == kAutoMatchChoiceTemplate) {
      // 题干、选项、答案、remark 字段名自动识别
      String stem = fieldMap['Question'] ?? fieldMap.values.firstOrNull ?? '';
      String options = fieldMap['Options'] ?? '';
      final answer = fieldMap['Answer'] ?? '';
      final remark = fieldMap['remark'] ?? fieldMap['Remark'] ?? '';
      // 渲染选项，自动高亮答案
      String optionsHtml = '';
      for (int i = 0; i < options.length; i++) {
        final label = String.fromCharCode('A'.codeUnitAt(0) + i);
        final value = options[i];
        final isCorrect = answer.contains(label);
        optionsHtml += '<div style="margin:4px 0;padding:6px;border-radius:6px;${isCorrect ? 'background:#d0ffd0;font-weight:bold;' : 'background:#f8f8f8;'}">'
          '<b>$label.</b> $value'
          '${isCorrect ? ' <span style="color:green;">✔</span>' : ''}'
          '</div>';
      }
      String remarkHtml = remark.isNotEmpty ? '<div style="margin-top:16px;padding:8px;background:#f0f0ff;border-radius:6px;color:#333;"><b>解析：</b>$remark</div>' : '';
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
  <style>
    body { font-family: system-ui, sans-serif; font-size: 18px; padding: 16px; }
    .stem { margin-bottom: 16px; }
    .options { margin-bottom: 16px; }
  </style>
</head>
<body>
  <div class="stem">$stem</div>
  <div class="r">$optionsHtml</div>
  $remarkHtml
</body>
</html>
''';
    }
    // 其它类型卡片渲染（只渲染主要字段）
    final displayFields = ['Expression', 'Reading', 'Meaning', 'Audio', 'Image_URI'];
    String content = '';
    for (final key in displayFields) {
      if (fieldMap.containsKey(key) && fieldMap[key]!.trim().isNotEmpty) {
        content += '<div style="margin-bottom:8px;"><b>' + key + ':</b><br>' + fieldMap[key]! + '</div>';
      }
    }
    if (content.trim().isEmpty) content = '（无内容）';
    String template = notetype?.config ?? '';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  $template
  <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
</head>
<body>
$content
</body>
</html>
''';
  }

  String _wrapHtml(String content) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
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
    if (_notes.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _notes.length;
      _saveProgress(_currentIndex);
      _loadCurrentCard();
    });
  }

  void _prevCard() {
    if (_notes.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _notes.length) % _notes.length;
      _saveProgress(_currentIndex);
      _loadCurrentCard();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_notes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('刷卡')),
        body: const Center(child: Text('无卡片')),
      );
    }
    final note = _notes[_currentIndex];
    final notetype = _cardNotetypes.firstWhereOrNull((n) => n.id == note.mid);
    if (notetype != null && notetype.name == kAutoMatchChoiceTemplate) {
      final fieldsForType = _fields.where((f) => f.notetypeId == note.mid).toList()..sort((a, b) => a.ord.compareTo(b.ord));
      final fieldMap = <String, String>{};
      for (int i = 0; i < fieldsForType.length && i < note.flds.length; i++) {
        fieldMap[fieldsForType[i].name] = note.flds[i];
      }
      final stem = fieldMap['Question'] ?? fieldMap.values.firstOrNull ?? '';
      final optionsRaw = fieldMap['Options'] ?? '';
      final options = optionsRaw.split(RegExp(r'<br>|\n')).where((s) => s.trim().isNotEmpty).toList();
      final answer = fieldMap['Answer'] ?? '';
      final remark = fieldMap['remark'] ?? fieldMap['Remark'] ?? '';
      final screenHeight = MediaQuery.of(context).size.height;
      return Scaffold(
        appBar: AppBar(
          title: Text('刷卡 ( ${_currentIndex + 1}/${_notes.length})'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. 题干区（美化：外层Padding+Container+圆角阴影+ClipRRect）
              Flexible(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      // borderRadius: BorderRadius.circular(12),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Colors.black12,
                      //     blurRadius: 6,
                      //     offset: Offset(0, 2),
                      //   ),
                      // ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: WebViewWidget(controller: _stemController),
                    ),
                  ),
                ),
              ),
              // 2. 选项区（ListView，Flexible分配空间，超出可滚动）
              Flexible(
                flex: 4,
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final label = String.fromCharCode('A'.codeUnitAt(0) + i);
                    final value = options[i];
                    final isCorrect = answer.contains(label);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: RadioListTile<int>(
                        value: i,
                        groupValue: _selectedIndex,
                        onChanged: _showAnswer ? null : (v) => setState(() => _selectedIndex = v),
                        title: Text(
                          '$label. $value',
                          style: TextStyle(
                            fontSize: 16,
                            color: _showAnswer
                                ? (isCorrect
                                    ? Colors.green[800]
                                    : (_selectedIndex == i ? Colors.red[800] : null))
                                : null,
                          ),
                          softWrap: true,
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                        tileColor: _showAnswer
                            ? (isCorrect
                                ? Colors.green.withOpacity(0.10)
                                : (_selectedIndex == i ? Colors.red.withOpacity(0.10) : null))
                            : null,
                      ),
                    );
                  },
                ),
              ),
              // 3. 答案/解析区（隐藏/显示，约2行高）
              if (_showAnswer && remark.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    height: 64,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: WebViewWidget(controller: _remarkController),
                    ),
                  ),
                ),
              // 4. 操作按钮区（显示答案等，居中）
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _selectedIndex != null && !_showAnswer
                          ? () => setState(() => _showAnswer = true)
                          : null,
                      child: const Text('显示答案'),
                    ),
                    // 这里可添加更多操作按钮
                  ],
                ),
              ),
              // 5. 底部按钮区（上一题/下一题，固定底部）
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.navigate_before),
                      label: const Text('上一题'),
                      onPressed: _prevCard,
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
        ),
      );
    }
    // 其它类型保持原有逻辑
    final html = _composeCardHtml(note);
    return Scaffold(
      appBar: AppBar(
        title: Text('刷卡 ( ${_currentIndex + 1}/${_notes.length})'),
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
              'mediaDir=${_mediaDir ?? "null"}\nnote.mid: ${note.mid}',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
          Expanded(child: WebViewWidget(key: ValueKey(_currentIndex), controller: _controller)),
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