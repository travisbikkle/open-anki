import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:open_anki/src/rust/api/simple.dart';
import 'package:open_anki/src/rust/frb_generated.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'src/model.dart';
import 'src/db.dart';
import 'src/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ImportAnkiPage(),
    );
  }
}

class ImportAnkiPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<ImportAnkiPage> createState() => _ImportAnkiPageState();
}

class _ImportAnkiPageState extends ConsumerState<ImportAnkiPage> {
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    ref.read(decksProvider.notifier).loadDecks();
  }

  Future<String> _calcFileMd5(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return md5.convert(bytes).toString();
  }

  Future<String?> _inputDeckNameDialog(String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入题库名称'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('确定')),
        ],
      ),
    );
  }

  Future<void> importApkg() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      FilePickerResult? picked = await FilePicker.platform.pickFiles();
      if (picked == null || picked.files.single.path == null) {
        setState(() { loading = false; });
        return;
      }
      String path = picked.files.single.path!;
      final deckId = await _calcFileMd5(path);
      final decks = ref.read(decksProvider);
      if (decks.any((d) => d.deckId == deckId)) {
        setState(() { loading = false; });
        showDialog(context: context, builder: (_) => const AlertDialog(title: Text('该题库已存在，无需重复导入')));
        return;
      }
      String defaultName = path.split(Platform.pathSeparator).last.split('.').first;
      String? deckName = await _inputDeckNameDialog(defaultName);
      if (deckName == null || deckName.isEmpty) deckName = defaultName;
      // 名称唯一性处理
      final existNames = decks.map((d) => d.deckName).toSet();
      String finalName = deckName;
      int suffix = 1;
      while (existNames.contains(finalName)) {
        finalName = '$deckName（$suffix）';
        suffix++;
      }
      final res = await parseApkg(path: path);
      final notes = res.notes.map((n) => AnkiNote(
        id: n.id.toInt(),
        guid: n.guid,
        mid: n.mid.toInt(),
        flds: n.flds,
        deckId: deckId,
        deckName: finalName,
      )).toList();
      await AnkiDb.clearNotesByDeck(deckId);
      await AnkiDb.insertNotes(notes, deckId);
      await ref.read(decksProvider.notifier).loadDecks();
      setState(() { loading = false; });
      if (!mounted) return;
      _showDeckSelectAndStart(deckId: deckId);
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void _showDeckSelectAndStart({String? deckId}) async {
    final decks = ref.read(decksProvider);
    String? selectedDeck = deckId;
    if (decks.isEmpty) return;
    if (selectedDeck == null || !decks.any((d) => d.deckId == selectedDeck)) {
      selectedDeck = await showDialog<String>(
        context: context,
        builder: (context) => DeckSelectDialog(decks: decks),
      );
    }
    if (selectedDeck != null) {
      ref.read(currentIndexProvider.notifier).state = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CardReviewPage(deckId: selectedDeck!)),
      );
    }
  }

  void _gotoDeckManager() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckManagerPage()));
  }

  @override
  Widget build(BuildContext context) {
    final decks = ref.watch(decksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('导入anki卡片')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: loading ? null : importApkg,
              child: const Text('导入anki卡片'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: decks.isNotEmpty
                  ? () => _showDeckSelectAndStart()
                  : null,
              child: const Text('开始刷题'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _gotoDeckManager,
              child: const Text('题库管理'),
            ),
            if (loading) const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            if (error != null) Text('错误: $error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class DeckSelectDialog extends StatelessWidget {
  final List<DeckInfo> decks;
  const DeckSelectDialog({required this.decks, super.key});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择题库'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: decks.length,
          itemBuilder: (context, idx) {
            final deck = decks[idx];
            return ListTile(
              title: Text('${deck.deckName} (${deck.cardCount}题)'),
              onTap: () => Navigator.of(context).pop(deck.deckId),
            );
          },
        ),
      ),
    );
  }
}

class DeckManagerPage extends ConsumerStatefulWidget {
  const DeckManagerPage({super.key});
  @override
  ConsumerState<DeckManagerPage> createState() => _DeckManagerPageState();
}

class _DeckManagerPageState extends ConsumerState<DeckManagerPage> {
  @override
  void initState() {
    super.initState();
    ref.read(decksProvider.notifier).loadDecks();
  }

  void _deleteDeck(String deckId) async {
    await AnkiDb.deleteDeck(deckId);
    await ref.read(decksProvider.notifier).loadDecks();
    setState(() {});
  }

  void _startDeck(String deckId) {
    ref.read(currentIndexProvider.notifier).state = 0;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CardReviewPage(deckId: deckId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decks = ref.watch(decksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('题库管理')),
      body: ListView.builder(
        itemCount: decks.length,
        itemBuilder: (context, idx) {
          final deck = decks[idx];
          return Card(
            child: ListTile(
              title: Text('${deck.deckName} (${deck.cardCount}题)'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _startDeck(deck.deckId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('确认删除'),
                          content: Text('确定要删除题库“${deck.deckName}”吗？'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
                          ],
                        ),
                      );
                      if (confirm == true) _deleteDeck(deck.deckId);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CardReviewPage extends ConsumerStatefulWidget {
  final String deckId;
  const CardReviewPage({required this.deckId, super.key});
  @override
  ConsumerState<CardReviewPage> createState() => _CardReviewPageState();
}

class _CardReviewPageState extends ConsumerState<CardReviewPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  Future<void> _loadDeck() async {
    await ref.read(notesProvider.notifier).loadFromDb(widget.deckId);
    final idx = await AnkiDb.loadProgress(widget.deckId);
    ref.read(currentIndexProvider.notifier).state = idx;
    setState(() { _loading = false; });
  }

  void _saveProgress(int idx) {
    AnkiDb.saveProgress(widget.deckId, idx);
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final currentIndex = ref.watch(currentIndexProvider);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (notes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('刷卡')),
        body: const Center(child: Text('无卡片')),
      );
    }
    final note = notes[currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('刷卡 (${currentIndex + 1}/${notes.length})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < note.flds.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: _FieldContent(
                              content: note.flds[i],
                              mediaFiles: const {}, // 持久化后暂不支持媒体
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: currentIndex > 0
                      ? () {
                          ref.read(currentIndexProvider.notifier).state--;
                          _saveProgress(currentIndex - 1);
                        }
                      : null,
                  child: const Text('上一题'),
                ),
                ElevatedButton(
                  onPressed: currentIndex < notes.length - 1
                      ? () {
                          ref.read(currentIndexProvider.notifier).state++;
                          _saveProgress(currentIndex + 1);
                        }
                      : null,
                  child: const Text('下一题'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldContent extends StatelessWidget {
  final String content;
  final Map<String, Uint8List> mediaFiles;
  const _FieldContent({required this.content, required this.mediaFiles});

  @override
  Widget build(BuildContext context) {
    // 支持 <br> 换行
    String normalized = content.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    final imgReg = RegExp('<img[^>]*src=["\"]([^"\'>]+)["\"][^>]*>');
    final soundReg = RegExp(r'\[sound:([^\]]+)\]');
    List<InlineSpan> spans = [];
    int last = 0;
    final matches = [
      ...imgReg.allMatches(normalized),
      ...soundReg.allMatches(normalized),
    ]..sort((a, b) => a.start.compareTo(b.start));
    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: normalized.substring(last, m.start)));
      }
      if (m.groupCount > 0) {
        final fname = m.group(1)!;
        if (m.pattern == imgReg.pattern && mediaFiles.containsKey(fname)) {
          spans.add(WidgetSpan(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Image.memory(mediaFiles[fname]!, height: 40),
          )));
        } else if (m.pattern == soundReg.pattern && mediaFiles.containsKey(fname)) {
          spans.add(WidgetSpan(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _AudioPlayerWidget(bytes: mediaFiles[fname]!, filename: fname),
          )));
        } else {
          spans.add(TextSpan(text: m.group(0)));
        }
      }
      last = m.end;
    }
    if (last < normalized.length) {
      spans.add(TextSpan(text: normalized.substring(last)));
    }
    return RichText(
      text: TextSpan(style: const TextStyle(color: Colors.black, fontSize: 16), children: spans),
      textAlign: TextAlign.left,
      softWrap: true,
    );
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final Uint8List bytes;
  final String filename;
  const _AudioPlayerWidget({required this.bytes, required this.filename});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  late final AudioPlayer _player;
  String? _localPath;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _prepareFile();
    _player.onPlayerComplete.listen((_) {
      setState(() { _playing = false; });
    });
  }

  Future<void> _prepareFile() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${widget.filename}');
    await file.writeAsBytes(widget.bytes, flush: true);
    setState(() { _localPath = file.path; });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_localPath == null) {
      return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return IconButton(
      icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
      onPressed: () async {
        if (_playing) {
          await _player.stop();
          setState(() { _playing = false; });
        } else {
          await _player.play(DeviceFileSource(_localPath!));
          setState(() { _playing = true; });
        }
      },
    );
  }
}
