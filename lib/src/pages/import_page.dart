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
import '../constants.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/snack_bar.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});
  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  String? error;
  bool loading = false;
  bool importing = false;
  final Map<String, Color> _deckColors = {};
  Map<String, Map<String, String>> _deckMediaFiles = {}; // deckId -> {文件名: 本地路径}

  // 自动修复：为_deckMediaFiles加安全getter，防止key不存在时抛异常
  Map<String, String> getDeckMediaFiles(String deckId) {
    return _deckMediaFiles[deckId] ?? {};
  }

  Color getDeckColor(String deckId) {
    if (deckId.isEmpty) return Colors.grey[200]!;
    final idx = deckId.codeUnits.fold(0, (a, b) => a + b) % kMacaronColors.length;
    return kMacaronColors[idx];
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
        title: Text(AppLocalizations.of(context)!.inputDeckName),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(AppLocalizations.of(context)!.confirm)),
        ],
      ),
    );
  }

  Future<String?> _inputRenameDialog(String oldName) async {
    final controller = TextEditingController(text: oldName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.renameDeck),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(AppLocalizations.of(context)!.confirm)),
        ],
      ),
    );
  }

  Future<void> importApkg() async {
    setState(() {
      error = null;
    });
    try {
      FilePickerResult? picked = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (picked == null || picked.files.isEmpty) {
        setState(() { loading = false; });
        return;
      }
      setState(() { importing = true; });
      final appDocDir = await getApplicationDocumentsDirectory();
      int successCount = 0;
      for (final file in picked.files) {
        String? path = file.path;
        if (path == null) continue;
        final fileName = p.basenameWithoutExtension(path);
        String? deckName;
        deckName = fileName;
        final result = await extractApkg(apkgPath: path, baseDir: p.join(appDocDir.path, 'anki_data'));
        final existingDeck = await AppDb.getDeckById(result.md5);
        if (existingDeck != null) {
          if(mounted) {
            showCartoonSnackBar(
              context,
              AppLocalizations.of(context)!.deckExists(existingDeck.deckName),
              backgroundColor: Colors.deepOrangeAccent,
              icon: Icons.warning_amber_rounded,
            );
          }
          continue;
        }
        int cardCount = (await getCardCountFromDeck(appDocDir: appDocDir.path, md5: result.md5)).toInt();
        await AppDb.insertDeck(result.md5, deckName, result.md5, mediaMap: result.mediaMap, version: result.version, cardCount: cardCount);
        final sqlitePath = p.join(appDocDir.path, 'anki_data', result.md5, 'collection.sqlite');
        final cardIds = (await getAllNoteIds(sqlitePath: sqlitePath, version: result.version)).map((e) => e.toInt()).toList();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        for (final cardId in cardIds) {
          await AppDb.upsertCardScheduling(CardScheduling(
            cardId: cardId,
            stability: 0.0,
            difficulty: 5.0,
            due: now,
          ));
          await AppDb.insertCardMapping(cardId, result.md5);
        }
        _deckColors[result.md5] = kMacaronColors[DateTime.now().millisecondsSinceEpoch % kMacaronColors.length];
        successCount++;
      }
      ref.invalidate(allDecksProvider);
      setState(() { importing = false; });
      if (!mounted) return;
      if (successCount > 0) {
        showCartoonSnackBar(
          context,
          AppLocalizations.of(context)!.importSuccess(successCount),
          backgroundColor: Colors.green,
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        importing = false;
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
            if (importing)
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
                      final color = getDeckColor(deck.deckId);
                      return Card(
                        color: color,
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
                                      title: Text(AppLocalizations.of(context)!.rename),
                                      onTap: () {
                                        Navigator.pop(context, 'rename');
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete),
                                      title: Text(AppLocalizations.of(context)!.delete),
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
                                await AppDb.renameDeck(deck.deckId, newName);
                                ref.invalidate(allDecksProvider);
                                ref.invalidate(recentDecksProvider);
                              }
                            } else if (result == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('确认删除'),
                                  content: Text(AppLocalizations.of(context)!.confirmDeleteDeck(deck.deckName)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(AppLocalizations.of(context)!.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: Text(AppLocalizations.of(context)!.delete),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await AppDb.deleteDeck(deck.deckId);
                                ref.invalidate(allDecksProvider);
                                ref.invalidate(recentDecksProvider);
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
                error: (e, _) => Center(child: Text(AppLocalizations.of(context)!.loadFailed(e.toString()))),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FloatingActionButton(
                  onPressed: loading || importing ? null : importApkg,
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: importing
                      ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Icon(Icons.add, size: 32),
                ),
              ),
              // 自动导入隐藏入口，仅在debug/profile模式下可见
              if (!bool.fromEnvironment('dart.vm.product'))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ElevatedButton(
                    key: Key('auto_import_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () async {
                      setState(() { importing = true; error = null; });
                      try {
                        final appDocDir = await getApplicationDocumentsDirectory();
                        final file = File('${appDocDir.path}/anki21.apkg');
                        if (!await file.exists()) {
                          setState(() { error = AppLocalizations.of(context)!.fileNotFound('anki21.apkg'); importing = false; });
                          return;
                        }
                        final fileName = 'anki21';
                        final deckName = fileName;
                        final result = await extractApkg(apkgPath: file.path, baseDir: p.join(appDocDir.path, 'anki_data'));

                        final existingDeck = await AppDb.getDeckById(result.md5);
                        if (existingDeck == null) {
                          int cardCount = (await getCardCountFromDeck(appDocDir: appDocDir.path, md5: result.md5)).toInt();
                          await AppDb.insertDeck(result.md5, deckName, result.md5, mediaMap: result.mediaMap, version: result.version, cardCount: cardCount);
                          final sqlitePath = p.join(appDocDir.path, 'anki_data', result.md5, 'collection.sqlite');
                          final cardIds = (await getAllNoteIds(sqlitePath: sqlitePath, version: result.version)).map((e) => e.toInt()).toList();
                          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                          for (final cardId in cardIds) {
                            await AppDb.upsertCardScheduling(CardScheduling(
                              cardId: cardId,
                              stability: 0.0,
                              difficulty: 5.0,
                              due: now,
                            ));
                            await AppDb.insertCardMapping(cardId, result.md5);
                          }
                          ref.invalidate(allDecksProvider);
                        }
                        
                        setState(() { importing = false; });
                        if (!mounted) return;
                      } catch (e) {
                        setState(() { error = e.toString(); importing = false; });
                      }
                    },
                    child: const SizedBox(width: 1, height: 1), // 极小不可见
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 