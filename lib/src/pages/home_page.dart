import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../model.dart';
import '../widgets/deck_progress_tile.dart';
import '../widgets/dashboard.dart';
import '../db.dart';
import '../pages/card_review_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../constants.dart';
import '../pages/iap_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 只在每次启动App时弹一次IAP弹窗
bool _iapDialogShown = false;

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  Color getDeckColor(String deckId) {
    if (deckId.isEmpty) return Colors.grey[200]!;
    final idx = deckId.codeUnits.fold(0, (a, b) => a + b) % kMacaronColors.length;
    return kMacaronColors[idx];
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDecksAsync = ref.watch(allDecksProvider);
    final recentDecksAsync = ref.watch(recentDecksProvider);
    int totalCards = 0;
    int learnedCards = 0;
    int deckCount = 0;
    if (allDecksAsync.asData != null) {
      final decks = allDecksAsync.asData!.value;
      deckCount = decks.length;
      for (final d in decks) {
        totalCards += d.cardCount;
        learnedCards += (d.currentIndex + 1).clamp(0, d.cardCount);
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xffeaf6ff),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Dashboard(totalCards: totalCards, learnedCards: learnedCards, deckCount: deckCount),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(AppLocalizations.of(context)?.recentReview ?? 'Recent Review', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: recentDecksAsync.when(
                  data: (decks) {
                    final localDecks = List<DeckInfo>.from(decks);
                    return StatefulBuilder(
                      builder: (context, setState) => ListView.separated(
                        itemCount: localDecks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          if (idx >= localDecks.length) return const SizedBox.shrink();
                          final deck = localDecks[idx];
                          return Dismissible(
                            key: ValueKey(deck.deckId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              setState(() => localDecks.removeAt(idx));
                              ref.invalidate(recentDecksProvider);
                            },
                            child: Card(
                              color: getDeckColor(deck.deckId),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 1,
                              child: DeckProgressTile(
                                deck: deck,
                                onTap: () async {
                                  // 保持原有点击刷题逻辑
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
                                  final stats = await AppDb.getTodayStats(deck.deckId);
                                  final settings = await AppDb.getStudyPlanSettings(deck.deckId);
                                  if (stats == null || stats.newCardsLearned < settings.newCardsPerDay) {
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
                                showSettings: false,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('加载失败: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePageWrapper extends ConsumerStatefulWidget {
  const HomePageWrapper({super.key});
  @override
  ConsumerState<HomePageWrapper> createState() => _HomePageWrapperState();
}

class _HomePageWrapperState extends ConsumerState<HomePageWrapper> {
  bool _navigated = false;

  Future<void> _clearIapPrefsAndRestart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('trial_used');
    await prefs.remove('full_version_purchased');
    await prefs.remove('trial_start_date');
    if (mounted) {
      _iapDialogShown = false;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePageWrapper()),
        (route) => false,
      );
    }
  }

  void _showIapDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: IAPPage(
          onClose: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTabIndex = ref.watch(currentIndexProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: '清理IAP状态',
            onPressed: _clearIapPrefsAndRestart,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final trialStatusAsync = ref.watch(trialStatusProvider);
          if (currentTabIndex == 0 && !_iapDialogShown && trialStatusAsync.asData != null) {
            final trialStatus = trialStatusAsync.asData!.value;
            final bool isFree = !(trialStatus['trialUsed'] ?? false) && !(trialStatus['fullVersionPurchased'] ?? false);
            if (isFree) {
              _iapDialogShown = true;
              Future.microtask(() {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  useRootNavigator: false,
                  builder: (context) => WillPopScope(
                    onWillPop: () async => false,
                    child: IAPPage(
                      onClose: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                );
              });
            }
          }
          return const HomePage();
        },
      ),
    );
  }
} 