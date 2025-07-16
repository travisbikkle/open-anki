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

class CardReviewPage extends ConsumerStatefulWidget {
  final String deckId;
  final Map<String, Uint8List>? mediaFiles;
  const CardReviewPage({required this.deckId, this.mediaFiles, super.key});
  @override
  ConsumerState<CardReviewPage> createState() => _CardReviewPageState();
}

class _CardReviewPageState extends ConsumerState<CardReviewPage> {
  bool _loading = true;
  late Map<String, Uint8List> _mediaFiles;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _mediaFiles = widget.mediaFiles ?? {};
    _loadDeck();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadDeck() async {
    await ref.read(notesProvider.notifier).loadFromDb(widget.deckId);
    final idx = await AnkiDb.loadProgress(widget.deckId);
    ref.read(currentIndexProvider.notifier).state = idx;
    setState(() { _loading = false; });
  }

  void _saveProgress(int idx) {
    AnkiDb.saveProgress(widget.deckId, idx);
    AnkiDb.upsertRecentDeck(widget.deckId); // 记录最近刷题
    ref.read(decksProvider.notifier).loadDecks(); // 刷新首页最近刷题
    ref.invalidate(allDecksProvider); // 刷新题库管理界面
    ref.invalidate(recentDecksProvider); // 刷新首页最近刷题记录
  }

  Future<String?> _getMediaDir() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return '${appDocDir.path}/media/${widget.deckId}';
  }

  Future<Uint8List?> _findMedia(String fname) async {
    final mediaDir = await _getMediaDir();
    if (mediaDir == null) return null;
    final tryNames = <String>{
      fname,
      fname.trim(),
      fname.toLowerCase(),
      fname.trim().toLowerCase(),
    };
    try {
      final decoded = Uri.decodeComponent(fname);
      tryNames.add(decoded);
      tryNames.add(decoded.trim());
      tryNames.add(decoded.toLowerCase());
      tryNames.add(decoded.trim().toLowerCase());
    } catch (_) {}
    for (final name in tryNames) {
      final f = File('$mediaDir/$name');
      if (await f.exists()) {
        return await f.readAsBytes();
      }
    }
    return null;
  }

  Widget _renderField(String field) {
    // 渲染图片
    final imgReg1 = RegExp(r'<img[^>]*src="([^"]+)"[^>]*>');
    final imgReg2 = RegExp(r"<img[^>]*src='([^'>]+)'[^>]*>");
    final soundReg = RegExp(r'\[sound:([^\]]+)\]');
    List<InlineSpan> spans = [];
    int last = 0;
    for (final match in imgReg1.allMatches(field)) {
      if (match.start > last) {
        spans.add(TextSpan(text: field.substring(last, match.start)));
      }
      final fname = match.group(1)!;
      spans.add(WidgetSpan(
        child: FutureBuilder<Uint8List?>(
          future: _findMedia(fname),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Image.memory(snapshot.data!, height: 80),
              );
            } else {
              return Text('[图片缺失:$fname]', style: const TextStyle(color: Colors.red));
            }
          },
        ),
      ));
      last = match.end;
    }
    for (final match in imgReg2.allMatches(field)) {
      if (match.start > last) {
        spans.add(TextSpan(text: field.substring(last, match.start)));
      }
      final fname = match.group(1)!;
      spans.add(WidgetSpan(
        child: FutureBuilder<Uint8List?>(
          future: _findMedia(fname),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Image.memory(snapshot.data!, height: 80),
              );
            } else {
              return Text('[图片缺失:$fname]', style: const TextStyle(color: Colors.red));
            }
          },
        ),
      ));
      last = match.end;
    }
    // 剩余文本
    String rest = field.substring(last);
    // 渲染音频
    int last2 = 0;
    for (final match in soundReg.allMatches(rest)) {
      if (match.start > last2) {
        spans.add(TextSpan(text: rest.substring(last2, match.start)));
      }
      final fname = match.group(1)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: FutureBuilder<Uint8List?>(
          future: _findMedia(fname),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () async {
                  try {
                    final mediaDir = await _getMediaDir();
                    final filePath = '$mediaDir/$fname';
                    await _audioPlayer.setFilePath(filePath);
                    await _audioPlayer.play();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('音频播放失败: $e')),
                    );
                  }
                },
              );
            } else {
              return Text('[音频缺失:$fname]', style: const TextStyle(color: Colors.red));
            }
          },
        ),
      ));
      last2 = match.end;
    }
    if (last2 < rest.length) {
      spans.add(TextSpan(text: rest.substring(last2)));
    }
    return RichText(text: TextSpan(style: const TextStyle(color: Colors.black, fontSize: 16), children: spans));
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
                            child: _renderField(note.flds[i]),
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