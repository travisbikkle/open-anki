import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../db.dart';
import '../model.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:open_anki/src/rust/api/simple.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_html/flutter_html.dart';
import 'dart:convert'; // for base64Encode
import 'package:collection/collection.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sqflite/sqflite.dart'; // 新增导入
import 'package:open_anki/src/widgets/anki_template_renderer.dart';
import 'package:open_anki/src/pages/html_source_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../log_helper.dart';
import 'settings_page.dart';

const String kAutoMatchChoiceTemplate = '自动匹配-选择题模板';
const String kSqliteDBFileName = 'collection.sqlite';

class CardReviewPage extends ConsumerStatefulWidget {
  final String deckId;
  final Map<String, Uint8List>? mediaFiles;
  final Map<String, String>? mediaMap; // 文件名 -> 数字编号的映射
  final StudyMode mode; // 新增：学习模式
  const CardReviewPage({
    required this.deckId, 
    this.mediaFiles, 
    this.mediaMap, 
    this.mode = StudyMode.learn, // 默认为学习模式
    super.key,
  });
  @override
  ConsumerState<CardReviewPage> createState() => _CardReviewPageState();
}

class _CardReviewPageState extends ConsumerState<CardReviewPage> {
  bool _loading = true;
  List<int> _noteIds = [];
  int _currentIndex = 0;
  String? _mediaDir;
  String? _sqlitePath;
  String? _deckVersion;
  NoteExt? _currentNote;
  NotetypeExt? _currentNotetype;
  List<FieldExt> _currentFields = [];
  late WebViewController _controller;
  // 新增：当前卡片的调度信息
  CardScheduling? _currentScheduling;
  // 新增：到期卡片列表
  List<CardScheduling> _dueCards = [];
  // 新增交互状态
  int? _selectedIndex;
  bool _showAnswer = false;
  late WebViewController _stemController;
  late WebViewController _remarkController;
  int? _currentCardOrd;
  String? _currentQfmt;
  String? _currentAfmt;
  String? _currentConfig;
  String? _currentFront;
  String? _currentBack;
  bool _showBack = false;
  double _minFontSize = 18;
  String? _frontHtmlPath;
  String? _backHtmlPath;
  String? _pendingShow; // 'front' or 'back'
  Completer<void>? _flipCompleter;
  Completer<void>? _cardLoadCompleter;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'AnkiDebug',
        onMessageReceived: (JavaScriptMessage message) {
          LogHelper.log('WebView Debug: ${message.message}');
        },
      )
      ..addJavaScriptChannel(
        'AnkiSave',
        onMessageReceived: (JavaScriptMessage message) {
          // Wrap in an async IIFE (Immediately Invoked Function Expression) to handle futures
          () async {
            if (message.message == 'saved' && _pendingShow != null) {
              final pageToShow = _pendingShow;
              // Clear pending state immediately to prevent re-entry
              _pendingShow = null;
              
              try {
                // First, update the state, which schedules a rebuild
                if (mounted) {
                  setState(() {
                    _showBack = !_showBack;
                  });
                }
                // Then, trigger the page load. The completer will be handled
                // in onPageFinished or onWebResourceError.
                if (pageToShow == 'back') {
                  if (_backHtmlPath != null) {
                    await _controller.loadRequest(Uri.parse('file://$_backHtmlPath'));
                  }
                } else {
                  if (_frontHtmlPath != null) {
                    await _controller.loadRequest(Uri.parse('file://$_frontHtmlPath'));
                  }
                }
              } catch (e, s) {
                LogHelper.log('Error in AnkiSave channel: $e\n$s');
                if (_flipCompleter != null && !_flipCompleter!.isCompleted) {
                  _flipCompleter!.completeError(e, s);
                }
              }
            }
          }();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            LogHelper.log('WebView Error: ${error.description}');
            if (_flipCompleter != null && !_flipCompleter!.isCompleted) {
              _flipCompleter!.completeError(error);
            }
            if (_cardLoadCompleter != null && !_cardLoadCompleter!.isCompleted) {
              _cardLoadCompleter!.completeError(error);
            }
          },
          onPageFinished: (String url) async {
            // Inject JS to scale checkboxes and radios
            await _controller.runJavaScript('''
              (function() {
                var scale = 1.1;
                var fontSize = window.getComputedStyle(document.body).fontSize;
                var px = parseFloat(fontSize || '12');
                var size = Math.max(px, 12);
                var css = 'input[type=checkbox], input[type=radio] { width: ' + size + 'px !important; height: ' + size + 'px !important; min-width: ' + size + 'px !important; min-height: ' + size + 'px !important; zoom: ' + scale + '; vertical-align: middle; }';
                var style = document.createElement('style');
                style.innerHTML = css;
                document.head.appendChild(style);
              })();
            ''');
            
            // Complete the flip operation now that the page is fully loaded
            if (_flipCompleter != null && !_flipCompleter!.isCompleted) {
              _flipCompleter!.complete();
            }
            // Complete the card load operation
            if (_cardLoadCompleter != null && !_cardLoadCompleter!.isCompleted) {
              _cardLoadCompleter!.complete();
            }
          },
        ),
      );
    _loadFontSizeAndDeck();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<String?> _getDeckDir() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final deck = await AppDb.getDeckById(widget.deckId);
    if (deck == null) return null;
    return '${appDocDir.path}/anki_data/${deck.deckId}';
  }

  Future<void> _loadFontSizeAndDeck() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _minFontSize = prefs.getDouble('minFontSize') ?? 18;
    });
    await _loadDeck();
  }

  Future<void> _loadDeck() async {
    setState(() { _loading = true; });
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final deck = await AppDb.getDeckById(widget.deckId);
      if (deck == null) throw Exception('题库未找到');
      
      final deckDir = '${appDocDir.path}/anki_data/${deck.deckId}';
      final sqlitePath = '$deckDir/$kSqliteDBFileName';
      _sqlitePath = sqlitePath;
      _mediaDir = '$deckDir/unarchived_media';
      _deckVersion = deck.version ?? 'anki2';
      
      // 根据学习模式获取卡片
      switch (widget.mode) {
        case StudyMode.learn:
          // 获取今日计划的新卡片
          final settings = await AppDb.getStudyPlanSettings(widget.deckId) ?? 
            const StudyPlanSettings();
          final stats = await AppDb.getTodayStats(widget.deckId) ?? 
            DailyStudyStats(
              deckId: widget.deckId,
              date: DateTime.now(),
              newCardsLearned: 0,
              cardsReviewed: 0,
              totalTime: 0,
              correctCount: 0,
              totalCount: 0,
            );
          final newLimit = settings.newCardsPerDay - stats.newCardsLearned;
          if (newLimit <= 0) {
            _noteIds = [];
            break;
          }
          // 通过 Rust FFI 获取新卡片 id
          _noteIds = (await getNewNoteIds(sqlitePath: sqlitePath, limit: BigInt.from(newLimit), version: _deckVersion!)).map((e) => e.toInt()).toList();
          break;
          
        case StudyMode.review:
          // 获取今日计划的复习卡片
          final settings = await AppDb.getStudyPlanSettings(widget.deckId) ?? 
            const StudyPlanSettings();
          final stats = await AppDb.getTodayStats(widget.deckId) ?? 
            DailyStudyStats(
              deckId: widget.deckId,
              date: DateTime.now(),
              newCardsLearned: 0,
              cardsReviewed: 0,
              totalTime: 0,
              correctCount: 0,
              totalCount: 0,
            );
          final reviewLimit = settings.reviewsPerDay - stats.cardsReviewed;
          if (reviewLimit <= 0) {
            _noteIds = [];
            break;
          }
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          _dueCards = await AppDb.getDueCards(now);
          // 只取今日计划数量的到期卡片
          _noteIds = _dueCards.take(reviewLimit).map((e) => e.cardId).toList();
          break;
          
        case StudyMode.preview:
          // 通过 Rust FFI 获取所有卡片 id
          _noteIds = (await getAllNoteIds(sqlitePath: sqlitePath, version: _deckVersion!)).map((e) => e.toInt()).toList();
          break;
          
        case StudyMode.custom:
          // 通过 Rust FFI 获取所有卡片 id
          _noteIds = (await getAllNoteIds(sqlitePath: sqlitePath, version: _deckVersion!)).map((e) => e.toInt()).toList();
          break;
      }
      
      // 使用 deckId 获取进度
      final progress = await AppDb.getProgress(widget.deckId);
      final idx = progress?['current_card_id'] ?? 0;
      
      // Load the card at the saved index, or the first one.
      await _loadCurrentCard(initialIndex: idx);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载题库失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  Future<void> _saveProgress(int idx) async {
    await AppDb.saveProgress(widget.deckId, idx);
    await AppDb.upsertRecentDeck(widget.deckId);
    // 刷新 provider 来更新界面显示
    ref.invalidate(allDecksProvider);
    ref.invalidate(recentDecksProvider);
  }

    void printLongHtml(String html) {
      // Flutter 的 print 会截断超长字符串，这里分段输出
      const int chunkSize = 800;
      for (int i = 0; i < html.length; i += chunkSize) {
        final end = (i + chunkSize < html.length) ? i + chunkSize : html.length;
        LogHelper.log(html.substring(i, end));
      }
    }

  Future<void> _loadCurrentCard({int? initialIndex}) async {
    _cardLoadCompleter = Completer<void>();
    
    // Use the provided index or the existing one.
    // The switch to the new index happens inside setState after data is loaded.
    final indexToLoad = initialIndex ?? _currentIndex;

    LogHelper.log('[_loadCurrentCard] 开始加载卡片，索引: $indexToLoad');
    if (_noteIds.isEmpty || _mediaDir == null || indexToLoad < 0 || indexToLoad >= _noteIds.length || _sqlitePath == null || _deckVersion == null) {
      debugPrint('[_loadCurrentCard] 条件不足，无法加载卡片');
      if (!_cardLoadCompleter!.isCompleted) _cardLoadCompleter!.complete();
      return;
    }
    
    try {
      final noteId = _noteIds[indexToLoad];
      
      var scheduling = await AppDb.getCardScheduling(noteId);
      if (scheduling == null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        scheduling = CardScheduling(cardId: noteId, stability: 0.0, difficulty: 5.0, due: now);
        await AppDb.upsertCardScheduling(scheduling);
      }
      
      final result = await getDeckNote(sqlitePath: _sqlitePath!, noteId: noteId, version: _deckVersion!);
      
      final fieldsForType = List<FieldExt>.from(result.fields)..sort((a, b) => a.ord.compareTo(b.ord));
      final fieldMap = <String, String>{};
      for (int i = 0; i < fieldsForType.length && i < result.note.flds.length; i++) {
        fieldMap[fieldsForType[i].name] = result.note.flds[i];
      }
      
      final (frontPath, backPath) = await AnkiTemplateRenderer.renderFrontBackHtml(
        front: result.front, back: result.back, config: result.css,
        fieldMap: fieldMap, js: null, mediaDir: _mediaDir,
        minFontSize: _minFontSize, deckId: widget.deckId,
      );

      // --- ATOMIC STATE UPDATE ---
      // All data is ready. Now update the state in one go.
      if (mounted) {
        setState(() {
          _currentIndex = indexToLoad;
          _selectedIndex = null;
          _showAnswer = false;
          _currentNote = result.note;
          _currentNotetype = result.notetype;
          _currentFields = result.fields;
          _currentCardOrd = result.ord;
          _currentConfig = result.css;
          _currentFront = result.front;
          _currentBack = result.back;
          _showBack = false;
          _currentScheduling = scheduling;
          _frontHtmlPath = frontPath;
          _backHtmlPath = backPath;
        });
      }

      if (_frontHtmlPath != null) {
        await _controller.loadRequest(Uri.parse('file://$_frontHtmlPath'));
      } else {
        if (!_cardLoadCompleter!.isCompleted) _cardLoadCompleter!.complete();
      }
    } catch (e, s) {
      LogHelper.log('Error in _loadCurrentCard: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载卡片失败: $e')));
      }
      if (_cardLoadCompleter != null && !_cardLoadCompleter!.isCompleted) {
        _cardLoadCompleter!.completeError(e, s);
      }
    }
    
    await _cardLoadCompleter!.future;
  }

  Future<void> _nextCard() async {
    if (_noteIds.isEmpty) return;
    
    int prevIndex = _currentIndex;
    final int newIndex = (_currentIndex + 1) % _noteIds.length;
    
    await _loadCurrentCard(initialIndex: newIndex);
    await _saveProgress(newIndex);

    // 新增：如果已经是最后一题，再点“下一题”时弹窗
    if (_noteIds.isNotEmpty && prevIndex == _noteIds.length - 1) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('今日计划已完成！'),
            content: const Text('如需多刷题，请在题库点击齿轮按钮，增加每日刷题数。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _prevCard() async {
    if (_noteIds.isEmpty) return;
    
    final int newIndex = (_currentIndex - 1 + _noteIds.length) % _noteIds.length;
    await _loadCurrentCard(initialIndex: newIndex);
    await _saveProgress(newIndex);
  }

  Widget _buildFeedbackButton(String emoji, String label, int value) {
    return ElevatedButton.icon(
      icon: Text(emoji, style: const TextStyle(fontSize: 20)),
      label: Text(label),
      style: ElevatedButton.styleFrom(minimumSize: const Size(64, 40)),
      onPressed: () async {
        if (_currentNote == null) return;
        // 获取当前卡片的调度参数
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000; // 转换为秒
        var scheduling = await AppDb.getCardScheduling(_currentNote!.id);
        if (scheduling == null) {
          // 如果没有调度参数，创建默认值
          scheduling = CardScheduling(
            cardId: _currentNote!.id,
            stability: 0.0, // 新卡片从0开始
            difficulty: 5.0,
            due: now,
          );
          await AppDb.upsertCardScheduling(scheduling);
        }
        
        // 根据设置选择调度算法
        final prefs = await SharedPreferences.getInstance();
        final algorithm = prefs.getString('schedulingAlgorithm') ?? 'fsrs';
        
        final result = algorithm == 'simple' 
          ? await updateCardScheduleSimple(
              stability: scheduling.stability,
              difficulty: scheduling.difficulty,
              lastReview: scheduling.due,
              rating: value,
              now: now,
            )
          : await updateCardSchedule(
              stability: scheduling.stability,
              difficulty: scheduling.difficulty,
              lastReview: scheduling.due,
              rating: value,
              now: now,
            );
        
        // 保存新的调度参数
        await AppDb.upsertCardScheduling(CardScheduling(
          cardId: _currentNote!.id,
          stability: result.stability,
          difficulty: result.difficulty,
          due: result.due,
        ));
        
        // 保存反馈和学习记录
        await AppDb.saveCardFeedback(_currentNote!.id, value);
        await AppDb.logStudy(widget.deckId, _currentNote!.id);
        await _nextCard();
      },
      onLongPress: () async {
        // 预览此选项的复习时间
        if (_currentNote == null) return;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final scheduling = await AppDb.getCardScheduling(_currentNote!.id);
        if (scheduling == null) return;

        // 根据设置选择调度算法
        final prefs = await SharedPreferences.getInstance();
        final algorithm = prefs.getString('schedulingAlgorithm') ?? 'fsrs';
        
        final result = algorithm == 'simple' 
          ? await updateCardScheduleSimple(
              stability: scheduling.stability,
              difficulty: scheduling.difficulty,
              lastReview: scheduling.due,
              rating: value, // 直接使用 value
              now: now,
            )
          : await updateCardSchedule(
              stability: scheduling.stability,
              difficulty: scheduling.difficulty,
              lastReview: scheduling.due,
              rating: value, // 直接使用 value
              now: now,
            );

        final dueDate = DateTime.fromMillisecondsSinceEpoch(result.due * 1000);
        final dueIn = result.due - now;
        String dueText;
        if (dueIn < 3600) {
          dueText = '${(dueIn / 60).round()} 分钟后';
        } else if (dueIn < 86400) {
          dueText = '${(dueIn / 3600).round()} 小时后';
        } else {
          dueText = '${(dueIn / 86400).round()} 天后';
        }

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('如果选择"$label"'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('下次复习时间: $dueText'),
                Text('具体时间: ${dueDate.toString().substring(0, 16)}'),
                const SizedBox(height: 8),
                Text('稳定性将变为: ${result.stability.toStringAsFixed(1)}'),
                Text('难度将变为: ${result.difficulty.toStringAsFixed(1)}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      },
    );
  }

  // 修改调度信息显示
  Widget _buildSchedulingInfo() {
    if (_currentScheduling == null) return const SizedBox.shrink();
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final dueDate = DateTime.fromMillisecondsSinceEpoch(_currentScheduling!.due * 1000);
    final dueIn = _currentScheduling!.due - now;
    
    String dueText;
    if (dueIn < 0) {
      dueText = '已过期 ${(-dueIn / 3600).round()} 小时';
    } else if (dueIn < 3600) {
      dueText = '${(dueIn / 60).round()} 分钟后复习';
    } else if (dueIn < 86400) {
      dueText = '${(dueIn / 3600).round()} 小时后复习';
    } else {
      dueText = '${(dueIn / 86400).round()} 天后复习';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('稳定性: ${_currentScheduling!.stability.toStringAsFixed(1)}'),
              Text('难度: ${_currentScheduling!.difficulty.toStringAsFixed(1)}'),
              Text('下次复习: $dueText'),
              Text('具体时间: ${dueDate.toString().substring(0, 16)}'),
              const SizedBox(height: 4),
              const Text('长按反馈按钮可预览下次复习时间', 
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[build] _loading=$_loading, _noteIds=${_noteIds.length}, _currentIndex=$_currentIndex, _currentNote=${_currentNote != null}, _currentNotetype=${_currentNotetype != null}');
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_noteIds.isEmpty) {
      debugPrint('[build] _noteIds 为空');
      return Scaffold(
        appBar: AppBar(title: const Text('刷卡')),
        body: const Center(child: Text('无卡片')),
      );
    }
    if (_currentNote == null) {
      debugPrint('[build] _currentNote 为空');
      return Scaffold(
        appBar: AppBar(title: const Text('刷卡')),
        body: const Center(child: Text('卡片加载失败')),
      );
    }
    final note = _currentNote;
    // 合并模式下，切换正反面用JS，不再重新loadHtmlString
    return Scaffold(
      appBar: AppBar(
        title: Text('今日卡片 ( ${_currentIndex + 1}/${_noteIds.length})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) {
                  String deckId = widget.deckId;
                  final cardId = note?.id.toString() ?? '';
                  final version = _deckVersion ?? '';
                  final flds = note?.fieldNames.join(' | ') ?? '';
                  final notetype = note?.notetypeName ?? '';
                  return Dialog(
                    backgroundColor: Colors.white.withOpacity(0.7),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 400,
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                        minWidth: 200,
                        minHeight: 100,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: DefaultTextStyle(
                            style: const TextStyle(color: Colors.black, fontSize: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('卡片信息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 12),
                                Text('牌组ID: $deckId'),
                                Text('模板名称: $notetype'),
                                const SizedBox(height: 8),
                                Text('卡片ID: $cardId'),
                                Text('版本: $version'),
                                Text('字段: $flds'),
                                // 新增调度信息
                                if (_currentScheduling != null) ...[
                                  const SizedBox(height: 8),
                                  Text('稳定性: 	${_currentScheduling!.stability.toStringAsFixed(1)}'),
                                  Text('难度: 	${_currentScheduling!.difficulty.toStringAsFixed(1)}'),
                                  Text('下次复习: 	${DateTime.fromMillisecondsSinceEpoch(_currentScheduling!.due * 1000).toString().substring(0, 16)}'),
                                ],
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('关闭', style: TextStyle(color: Colors.black)),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () async {
                                      // 显示当前加载的 HTML 文件内容
                                      final currentPath = _showBack ? _backHtmlPath! : _frontHtmlPath!;
                                      final htmlFile = File(currentPath);
                                      if (await htmlFile.exists()) {
                                        final htmlContent = await htmlFile.readAsString();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => HtmlSourcePage(html: htmlContent),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('查看卡片源码', style: TextStyle(color: Colors.blue)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 0,
          ),
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! < 0) {
                    // 左滑，下一题
                    _nextCard();
                  } else if (details.primaryVelocity! > 0) {
                    // 右滑，上一题
                    _prevCard();
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: WebViewWidget(
                    key: ValueKey(_currentIndex),
                    controller: _controller,
                  ),
                ),
              ),
            ),
          ),
                    if (_showBack && _currentNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 0, left: 16, right: 16, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFeedbackButton('😄', '简单', 2), // 改为 2 (Good)
                  const SizedBox(width: 12),
                  _buildFeedbackButton('😐', '一般', 1), // 改为 1 (Hard)
                  const SizedBox(width: 12),
                  _buildFeedbackButton('😫', '困难', 0), // 改为 0 (Again)
                ],
              ),
            ),
          SafeArea(
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.navigate_before),
                    label: const Text('上一题'),
                    onPressed: _prevCard,
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton(
                    onPressed: () async {
                      LogHelper.log('=== 显示答案按钮被点击 ===');

                      // Prevent double-tapping while a flip is in progress
                      if (_flipCompleter != null && !_flipCompleter!.isCompleted) {
                        return;
                      }
                      _flipCompleter = Completer<void>();

                      if (!_showBack) {
                        // 只在从正面切到背面时计入已学习
                        await AppDb.incrementTotalLearned(widget.deckId);
                        if (context.mounted) {
                          ref.invalidate(allDecksProvider);
                          ref.invalidate(recentDecksProvider);
                        }
                      }
                      if (_showBack) {
                        _pendingShow = 'front';
                      } else {
                        _pendingShow = 'back';
                      }
                      
                      try {
                        await _controller.runJavaScript('trigger_save()');
                        // Wait for the JS roundtrip and subsequent page load to complete
                        await _flipCompleter!.future;
                      } catch (e, s) {
                        // If JS fails or page load fails, this will catch it
                        LogHelper.log('Error during flip operation: $e\n$s');
                        // Fail the test gracefully if something goes wrong
                        // fail('Flip operation failed: $e'); // This line was removed as per the edit hint
                      }
                    },
                    child: Text(_showBack ? '返回正面' : '显示答案'),
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.navigate_next),
                    label: const Text('下一题'),
                    onPressed: _nextCard,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 