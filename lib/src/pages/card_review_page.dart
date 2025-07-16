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
  List<dynamic> _notes = [];

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
    // 通过 Rust FFI 读取 collection.sqlite 卡片
    setState(() { _loading = true; });
    try {
      // 假设 deckId 即为 md5，AppDb 可查到 apkg 路径
      final allDecks = await AppDb.getAllDecks();
      final deck = allDecks.firstWhere(
        (d) => (d['md5'] ?? d['id'].toString()) == widget.deckId,
        orElse: () => <String, dynamic>{},
      );
      if (deck.isEmpty) throw Exception('题库未找到');
      final apkgPath = deck['apkg_path'] as String;
      // collection.sqlite 路径
      final sqlitePath = '$apkgPath/collection.sqlite';
      print('DEBUG: apkgPath: $apkgPath');
      print('DEBUG: sqlitePath: $sqlitePath');
      // 1. 调用 Rust FFI 获取卡片
      final result = await getDeckNotes(sqlitePath: sqlitePath);
      setState(() {
        _notes = result.notes;
      });
      // 2. 进度管理
      final progress = await AppDb.getProgress(deck['id'] as int);
      final idx = progress?['current_card_id'] ?? 0;
      ref.read(currentIndexProvider.notifier).state = idx;
    } catch (e) {
      // 错误处理
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载题库失败: $e')));
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _saveProgress(int idx) async {
    // 进度管理用 AppDb
    final allDecks = await AppDb.getAllDecks();
    final deck = allDecks.firstWhere(
      (d) => (d['md5'] ?? d['id'].toString()) == widget.deckId,
      orElse: () => <String, dynamic>{},
    );
    if (deck.isEmpty) return;
    final deckId = deck['id'] as int;
    await AppDb.saveProgress(deckId, idx);
    await AppDb.upsertRecentDeck(deckId);
    // 刷新 UI
    ref.invalidate(allDecksProvider);
    ref.invalidate(recentDecksProvider);
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

  Widget _renderField(String field, {String? notetypeName}) {
    // 针对“自动匹配-选择题模板”自动分行加A/B/C/D
    if (notetypeName == '自动匹配-选择题模板') {
      // 题干和选项之间用<br>分隔，选项之间没有分隔符，自动分行并加A/B/C/D
      final parts = field.split('<br>');
      if (parts.length >= 2) {
        final question = parts[0];
        // 选项部分合并后按大写字母开头分割
        final optionsRaw = parts.sublist(1).join('<br>');
        // 尝试用换行或大写字母加点分割
        final optionList = optionsRaw.split(RegExp(r'(?=[A-Z][A-Z]?\s?\()|(?<=\.)\s+)'));
        final optionLabels = ['A', 'B', 'C', 'D', 'E', 'F'];
        final optionsHtml = optionList.asMap().entries.map((e) =>
          '<div><b>${optionLabels[e.key]}.</b> ${e.value.trim()}</div>'
        ).join();
        final html = '$question<br>$optionsHtml';
        return Html(
          data: html,
          extensions: [
            TagExtension(
              tagsToExtend: {"img"},
              builder: (context) {
                final src = context.attributes['src'] ?? '';
                return FutureBuilder<Uint8List?>(
                  future: _findMedia(src),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Image.memory(snapshot.data!, height: 80),
                      );
                    } else {
                      return Text('[图片缺失:$src]', style: const TextStyle(color: Colors.red));
                    }
                  },
                );
              },
            ),
            TagExtension(
              tagsToExtend: {"audio"},
              builder: (context) {
                final src = context.attributes['src'] ?? '';
                return FutureBuilder<Uint8List?>(
                  future: _findMedia(src),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return IconButton(
                        icon: const Icon(Icons.volume_up),
                        onPressed: () async {
                          try {
                            final mediaDir = await _getMediaDir();
                            final filePath = '$mediaDir/$src';
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
                      return Text('[音频缺失:$src]', style: const TextStyle(color: Colors.red));
                    }
                  },
                );
              },
            ),
          ],
        );
      }
    }
    // 其他模板保持原有HTML渲染
    String html = field.replaceAllMapped(
      RegExp(r'\[sound:([^\]]+)\]'),
      (m) => '<audio src="${m[1]}"></audio>',
    );
    return Html(
      data: html,
      extensions: [
        TagExtension(
          tagsToExtend: {"img"},
          builder: (context) {
            final src = context.attributes['src'] ?? '';
            return FutureBuilder<Uint8List?>(
              future: _findMedia(src),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Image.memory(snapshot.data!, height: 80),
                  );
                } else {
                  return Text('[图片缺失:$src]', style: const TextStyle(color: Colors.red));
                }
              },
            );
          },
        ),
        TagExtension(
          tagsToExtend: {"audio"},
          builder: (context) {
            final src = context.attributes['src'] ?? '';
            return FutureBuilder<Uint8List?>(
              future: _findMedia(src),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () async {
                      try {
                        final mediaDir = await _getMediaDir();
                        final filePath = '$mediaDir/$src';
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
                  return Text('[音频缺失:$src]', style: const TextStyle(color: Colors.red));
                }
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentIndexProvider);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_notes.isEmpty || currentIndex < 0 || currentIndex >= _notes.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('刷卡')),
        body: const Center(child: Text('无卡片')),
      );
    }
    final note = _notes[currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('刷卡 ( ${currentIndex + 1}/${_notes.length})'),
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
                            child: _renderField(note.flds[i], notetypeName: note.notetypeName),
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
                  onPressed: currentIndex < _notes.length - 1
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