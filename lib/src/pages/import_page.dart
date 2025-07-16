import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../providers.dart';
import '../db.dart';
import '../model.dart';
import 'package:open_anki/src/rust/api/simple.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});
  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  String? error;
  bool loading = false;

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
      showDialog(context: context, builder: (_) => const AlertDialog(title: Text('导入成功！')));
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
          ],
        ),
      ),
    );
  }
} 