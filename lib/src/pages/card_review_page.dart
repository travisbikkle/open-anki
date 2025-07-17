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
      final newMediaDir = '$deckDir/unarchived_media';
      setState(() {
        _notes = result.notes.cast<NoteExt>();
        _cardNotetypes = result.notetypes.cast<NotetypeExt>();
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
    final content = note.flds is List ? (note.flds as List).join('<br>') : note.flds.toString();
    debugPrint('【composeCardHtml】content: $content');
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>body{background:#222;color:#fff;font-size:18px;}</style>
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
    return Scaffold(
      appBar: AppBar(
        title: Text('刷卡 ( ${_currentIndex + 1}/${_notes.length})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: _prevCard,
          ),
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: _nextCard,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.all(8),
            child: Text(
              '调试信息：mediaDir=${_mediaDir ?? "null"}\nHTML为空: ${html.trim().isEmpty}',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
         Expanded(child: WebViewWidget(key: ValueKey(_currentIndex), controller: _controller)),
        ],
      ),
    );
  }
} 