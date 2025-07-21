import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../model.dart';
import '../pages/card_review_page.dart';
import '../db.dart';

class DeckProgressTile extends StatelessWidget {
  final DeckInfo deck;
  final VoidCallback? onTap;
  const DeckProgressTile({required this.deck, this.onTap, super.key});

  // 显示学习计划设置对话框
  Future<void> _showStudyPlanDialog(BuildContext context) async {
    final settings = await AppDb.getStudyPlanSettings(deck.deckId) ?? 
      const StudyPlanSettings();

    final result = await showDialog<StudyPlanSettings>(
      context: context,
      builder: (context) => StudyPlanDialog(
        initialSettings: settings,
        deckName: deck.deckName,
      ),
    );

    if (result != null) {
      await AppDb.saveStudyPlanSettings(deck.deckId, result);
    }
  }

  // 显示长按菜单（在手指位置弹出）
  Future<void> _showDeckMenu(BuildContext context, Offset position) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy
      ),
      items: [
        const PopupMenuItem(value: 'preview', child: Text('自由浏览')),
        const PopupMenuItem(value: 'rename', child: Text('重命名')),
        const PopupMenuItem(value: 'delete', child: Text('删除')),
      ],
    );

    if (result == null) return;
    if (!context.mounted) return;

    switch (result) {
      case 'rename':
        final newName = await showDialog<String>(
          context: context,
          builder: (context) => RenameDialog(
            initialName: deck.deckName,
          ),
        );
        if (newName != null) {
          await AppDb.renameDeck(deck.deckId, newName);
        }
        break;
      case 'preview':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CardReviewPage(
              deckId: deck.deckId,
              mode: StudyMode.preview,
            ),
          ),
        );
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除题库'),
            content: Text('确定要删除题库"${deck.deckName}"吗？此操作不可恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await AppDb.deleteDeck(deck.deckId);
          // 新增：刷新 provider
          if (context.mounted) {
            final container = ProviderScope.containerOf(context);
            container.invalidate(allDecksProvider);
            container.invalidate(recentDecksProvider);
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardCount = deck.cardCount;
    final learned = deck.totalLearned;
    final double progress = cardCount > 0 ? learned / cardCount : 0;
    
    return GestureDetector(
      onTap: onTap ?? () async {
        // 检查今日学习上限
        final canStudy = await AppDb.canStudyMore(deck.deckId);
        if (!canStudy) {
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('今日学习已达上限'),
              content: const Text('您可以通过题库设置按钮修改每日学习数量，或者选择自由浏览模式继续学习。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CardReviewPage(
                          deckId: deck.deckId,
                          mode: StudyMode.preview,
                        ),
                      ),
                    );
                  },
                  child: const Text('自由浏览'),
                ),
              ],
            ),
          );
          return;
        }
        
        // 获取今日统计
        final stats = await AppDb.getTodayStats(deck.deckId);
        final settings = await AppDb.getStudyPlanSettings(deck.deckId);
        
        // 判断应该优先学习新卡片还是复习
        if (stats == null || stats.newCardsLearned < settings.newCardsPerDay) {
          // 优先学习新卡片
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CardReviewPage(
                deckId: deck.deckId,
                mode: StudyMode.learn,
              ),
            ),
          );
        } else {
          // 新卡片已达上限，进入复习模式
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CardReviewPage(
                deckId: deck.deckId,
                mode: StudyMode.review,
              ),
            ),
          );
        }
      },
      onLongPressStart: (details) => _showDeckMenu(context, details.globalPosition),
      child: Container(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(deck.deckName),
              trailing: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showStudyPlanDialog(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Container(
                height: 16,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 16,
                        backgroundColor: Colors.grey[200],
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      '$learned/$cardCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// 学习计划设置对话框
class StudyPlanDialog extends StatefulWidget {
  final StudyPlanSettings initialSettings;
  final String deckName;

  const StudyPlanDialog({
    required this.initialSettings,
    required this.deckName,
    super.key,
  });

  @override
  State<StudyPlanDialog> createState() => _StudyPlanDialogState();
}

class _StudyPlanDialogState extends State<StudyPlanDialog> {
  late StudyPlanSettings _settings;
  
  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('学习计划'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('每日新卡片数', style: TextStyle(fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        if (_settings.newCardsPerDay > 5) {
                          setState(() {
                            _settings = _settings.copyWith(
                              newCardsPerDay: _settings.newCardsPerDay - 5,
                            );
                          });
                        }
                      },
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${_settings.newCardsPerDay}',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          _settings = _settings.copyWith(
                            newCardsPerDay: _settings.newCardsPerDay + 5,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('每日复习数量', style: TextStyle(fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        if (_settings.reviewsPerDay > 10) {
                          setState(() {
                            _settings = _settings.copyWith(
                              reviewsPerDay: _settings.reviewsPerDay - 10,
                            );
                          });
                        }
                      },
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${_settings.reviewsPerDay}',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          _settings = _settings.copyWith(
                            reviewsPerDay: _settings.reviewsPerDay + 10,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _settings),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

// 重命名对话框
class RenameDialog extends StatefulWidget {
  final String initialName;

  const RenameDialog({
    required this.initialName,
    super.key,
  });

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('重命名题库'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '题库名称',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
} 