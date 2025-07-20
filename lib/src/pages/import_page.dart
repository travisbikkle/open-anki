import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../db.dart';
import '../model.dart';
import 'card_review_page.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:open_anki/src/rust/api/simple.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../widgets/deck_progress_tile.dart';
import 'package:sqflite/sqflite.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});
  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  String? error;
  bool loading = false;
  Map<String, Map<String, String>> _deckMediaFiles = {}; // deckId -> {文件名: 本地路径}

  // 自动修复：为_deckMediaFiles加安全getter，防止key不存在时抛异常
  Map<String, String> getDeckMediaFiles(String deckId) {
    return _deckMediaFiles[deckId] ?? {};
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

  Future<String?> _inputRenameDialog(String oldName) async {
    final controller = TextEditingController(text: oldName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名题库'),
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
      FilePickerResult? picked = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (picked == null || picked.files.isEmpty) {
        setState(() { loading = false; });
        return;
      }
      final appDocDir = await getApplicationDocumentsDirectory();
      for (final file in picked.files) {
        String? path = file.path;
        if (path == null) continue;
        final fileName = p.basenameWithoutExtension(path);
        String? deckName;
        if (picked.files.length == 1) {
          deckName = await _inputDeckNameDialog(fileName);
          if (deckName == null || deckName.isEmpty) deckName = fileName;
        } else {
          deckName = fileName;
        }
        // 调用Rust端解压
        final result = await extractApkg(apkgPath: path, baseDir: p.join(appDocDir.path, 'anki_data'));
        // 统计卡片总数
        int cardCount = (await getCardCountFromDeck(appDocDir: appDocDir.path, md5: result.md5)).toInt();
        // 在AppDb登记索引，保存version和cardCount
        await AppDb.insertDeck(result.md5, deckName, result.md5, mediaMap: result.mediaMap, version: result.version, cardCount: cardCount);
      }
      // 强制刷新 provider
      ref.invalidate(allDecksProvider);
      setState(() { loading = false; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入成功'), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDecksAsync = ref.watch(allDecksProvider);
    return Scaffold(
      backgroundColor: const Color(0xffeaf6ff),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            if (loading)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('错误: $error', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            Expanded(
              child: allDecksAsync.when(
                data: (decks) {
                  final nameCount = <String, int>{};
                  for (final d in decks) {
                    nameCount[d.deckName] = (nameCount[d.deckName] ?? 0) + 1;
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: decks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final deck = decks[idx];
                      final showCount = (nameCount[deck.deckName] ?? 0) > 1;
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onLongPress: () async {
                            final result = await showModalBottomSheet<String>(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit),
                                      title: const Text('重命名'),
                                      onTap: () {
                                        Navigator.pop(context, 'rename');
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete),
                                      title: const Text('删除'),
                                      onTap: () {
                                        Navigator.pop(context, 'delete');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (result == 'rename') {
                              final newName = await _inputRenameDialog(deck.deckName);
                              if (newName != null && newName.isNotEmpty && newName != deck.deckName) {
                                await AppDb.updateDeckName(deck.deckId, newName);
                                ref.invalidate(allDecksProvider);
                              }
                            } else if (result == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('确认删除'),
                                  content: Text('确定要删除题库 "${deck.deckName}" 吗？此操作不可撤销。'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('删除'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await AppDb.deleteDeck(md5: deck.deckId);
                                ref.invalidate(allDecksProvider);
                              }
                            }
                          },
                          child: DeckProgressTile(deck: deck),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e')),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: loading ? null : importApkg,
              child: const Text('导入anki卡片'),
            ),
          ),
        ),
      ),
    );
  }
} 