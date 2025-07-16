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
      final decks = await AnkiDb.getAllDecks();
      int successCount = 0;
      final existNames = decks.map((d) => d['deck_name'] as String? ?? '').toSet();
      if (picked.files.length == 1) {
        final file = picked.files.first;
        String? path = file.path;
        if (path != null) {
          final deckId = await _calcFileMd5(path);
          if (!decks.any((d) => d['deck_id'] == deckId)) {
            String defaultName = path.split(Platform.pathSeparator).last.split('.').first;
            String? deckName = await _inputDeckNameDialog(defaultName);
            if (deckName == null || deckName.isEmpty) deckName = defaultName;
            // 名称唯一性处理
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
            successCount++;
          }
        }
      } else {
        for (final file in picked.files) {
          String? path = file.path;
          if (path == null) continue;
          final deckId = await _calcFileMd5(path);
          if (decks.any((d) => d['deck_id'] == deckId)) {
            // 已存在，跳过
            continue;
          }
          String deckName = path.split(Platform.pathSeparator).last.split('.').first;
          // 名称唯一性处理
          String finalName = deckName;
          int suffix = 1;
          while (existNames.contains(finalName)) {
            finalName = '$deckName（$suffix）';
            suffix++;
          }
          existNames.add(finalName);
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
          successCount++;
        }
      }
      ref.invalidate(allDecksProvider);
      setState(() { loading = false; });
      if (!mounted) return;
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入 $successCount 个题库！'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: '去首页',
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未导入新题库（可能已存在）'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _deleteDeck(String deckId) async {
    await AnkiDb.deleteDeck(deckId);
    await ref.read(decksProvider.notifier).loadDecks();
    setState(() {});
  }

  Future<void> _renameDeck(String deckId, String oldName) async {
    String? newName = await _inputRenameDialog(oldName);
    if (newName == null || newName.isEmpty || newName == oldName) return;
    final db = await AnkiDb.db;
    await db.update('notes', {'deck_name': newName}, where: 'deck_id = ?', whereArgs: [deckId]);
    ref.invalidate(allDecksProvider);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final allDecksAsync = ref.watch(allDecksProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (loading) const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            if (error != null) Text('错误: $error', style: const TextStyle(color: Colors.red)),
            Expanded(
              child: allDecksAsync.when(
                data: (decks) {
                  // 统计题库名出现次数
                  final nameCount = <String, int>{};
                  for (final d in decks) {
                    nameCount[d.deckName] = (nameCount[d.deckName] ?? 0) + 1;
                  }
                  return ListView.builder(
                    itemCount: decks.length,
                    itemBuilder: (context, idx) {
                      final deck = decks[idx];
                      final showCount = (nameCount[deck.deckName] ?? 0) > 1;
                      final displayName = showCount
                        ? '${deck.deckName}（${deck.cardCount}）'
                        : deck.deckName;
                      return Card(
                        child: ListTile(
                          title: Text(displayName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('进度：${deck.currentIndex + 1}/${deck.cardCount}'),
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: LinearProgressIndicator(
                                  value: deck.cardCount > 0 ? (deck.currentIndex + 1) / deck.cardCount : 0,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            ref.read(currentIndexProvider.notifier).state = 0;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CardReviewPage(deckId: deck.deckId)),
                            );
                          },
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
                              _renameDeck(deck.deckId, deck.deckName);
                            } else if (result == 'delete') {
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
                            }
                          },
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
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.primary,
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