import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:open_anki/src/rust/api/simple.dart';
import 'package:open_anki/src/rust/frb_generated.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
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

class ImportAnkiPage extends StatefulWidget {
  @override
  State<ImportAnkiPage> createState() => _ImportAnkiPageState();
}

class _ImportAnkiPageState extends State<ImportAnkiPage> {
  ApkgParseResult? result;
  String? error;
  bool loading = false;

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
      final res = await parseApkg(path: path);
      setState(() {
        result = res;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            if (loading) const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            if (error != null) Text('错误: $error', style: const TextStyle(color: Colors.red)),
            if (result != null) ...[
              const SizedBox(height: 16),
              Expanded(child: CardListView(result: result!)),
            ]
          ],
        ),
      ),
    );
  }
}

class CardListView extends StatelessWidget {
  final ApkgParseResult result;
  const CardListView({required this.result, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: result.notes.length,
      itemBuilder: (context, idx) {
        final note = result.notes[idx];
        return Card(
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
                      mediaFiles: result.mediaFiles,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
