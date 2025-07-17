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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
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
      final sqlitePath = '$deckDir/collection.sqlite';
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
    final note = _notes[_currentIndex];
    final html = _composeCardHtml(note);
    debugPrint('【WebView调试】baseUrl: file://${_mediaDir!}/');
    debugPrint('【WebView调试】HTML片段: ' + (html.length > 200 ? html.substring(0, 200) : html));
    _controller.loadHtmlString(
      html,
      baseUrl: 'file://${_mediaDir!}/',
    );
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
    // 自动匹配-选择题模板专用渲染
    if (notetype != null && notetype.name == '自动匹配-选择题模板') {
      // 题干、选项、答案、remark 字段名自动识别
      String stem = fieldMap['Question'] ?? fieldMap.values.firstOrNull ?? '';
      String optionsRaw = fieldMap['Options'] ?? '';
      // 选项用 <br> 或 \n 分割
      final options = optionsRaw.split(RegExp(r'<br>|\n')).where((s) => s.trim().isNotEmpty).toList();
      final answer = fieldMap['Answer'] ?? fieldMap['答案'] ?? '';
      final remark = fieldMap['remark'] ?? fieldMap['Remark'] ?? fieldMap['解析'] ?? '';
      
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
      // 题干、remark渲染
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
  <div class="options">$optionsHtml</div>
  $remarkHtml
</body>
</html>
''';
    }
    // 其它类型保持原有逻辑
    String content = note.flds is List ? (note.flds as List).join('<br>') : note.flds.toString();
    String template = notetype?.config ?? '';
    if (content.trim().isEmpty) content = '（无内容）';
    debugPrint('【composeCardHtml】content: $content');
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
    final html = _composeCardHtml(note);
    // 获取当前卡片的 notetype 名称
    String notetypeName = '';
    String noteMidStr = note.mid.toString().trim();
    String allNotetypeIds = _cardNotetypes.map((n) => n.id.toString().trim()).join(',');
    bool notetypeFound = false;
    try {
      final notetype = _cardNotetypes.firstWhere(
        (n) => n.id.toString().trim() == noteMidStr,
        orElse: () => NotetypeExt(id: -1, name: '', config: ''),
      );
      if (notetype.id != -1 && notetype.name != null) {
        notetypeName = notetype.name.toString();
        notetypeFound = true;
      }
    } catch (e) {}
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
              notetypeFound
                ? '调试信息：mediaDir=${_mediaDir ?? "null"}\nHTML为空: ${html.trim().isEmpty}\nnotetype: $notetypeName\nnote.mid: $noteMidStr\nall notetype ids: $allNotetypeIds'
                : '调试信息：mediaDir=${_mediaDir ?? "null"}\nHTML为空: ${html.trim().isEmpty}\n未找到notetype，note.mid: $noteMidStr\nall notetype ids: $allNotetypeIds',
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