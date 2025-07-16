import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../db.dart';

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
    AnkiDb.upsertRecentDeck(widget.deckId); // 记录最近刷题
    ref.read(decksProvider.notifier).loadDecks(); // 刷新首页最近刷题
    ref.invalidate(allDecksProvider); // 刷新题库管理界面
    ref.invalidate(recentDecksProvider); // 刷新首页最近刷题记录
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
                            child: Text(note.flds[i]),
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