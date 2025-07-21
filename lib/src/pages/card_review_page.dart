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
  const CardReviewPage({required this.deckId, this.mediaFiles, this.mediaMap, super.key});
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
          if (message.message == 'saved' && _pendingShow != null) {
            if (_pendingShow == 'back') {
              _controller.loadRequest(Uri.parse('file://$_backHtmlPath'));
            } else {
              _controller.loadRequest(Uri.parse('file://$_frontHtmlPath'));
            }
            setState(() {
              _showBack = !_showBack;
            });
            _pendingShow = null;
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            LogHelper.log('WebView Error: ${error.description}');
          },
          onPageFinished: (String url) async {
            // 注入JS放大checkbox和radio
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
    _loadDeck();
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
      
      // 获取到期的卡片
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _dueCards = await AppDb.getDueCards(now);
      
      if (_dueCards.isEmpty) {
        // 如果没有到期卡片，获取所有卡片ID
        final db = await openDatabase(sqlitePath);
        final idRows = await db.rawQuery('SELECT id FROM notes');
        _noteIds = idRows.map((e) => e['id'] as int).toList();
        await db.close();
      } else {
        // 使用到期卡片的ID
        _noteIds = _dueCards.map((e) => e.cardId).toList();
      }
      
      // 使用 deckId 获取进度
      final progress = await AppDb.getProgress(widget.deckId);
      final idx = progress?['current_card_id'] ?? 0;
      _currentIndex = _noteIds.indexOf(idx);
      if (_currentIndex < 0) _currentIndex = 0;
      await _loadCurrentCard();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载题库失败: $e')));
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _saveProgress(int idx) async {
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

  Future<void> _loadCurrentCard() async {
    LogHelper.log('[_loadCurrentCard] 开始加载卡片，索引: $_currentIndex');
    if (_noteIds.isEmpty || _mediaDir == null || _currentIndex < 0 || _currentIndex >= _noteIds.length || _sqlitePath == null || _deckVersion == null) {
      debugPrint('[_loadCurrentCard] 条件不足，无法加载卡片');
      LogHelper.log('_noteIds.isEmpty: ${_noteIds.isEmpty}');
      LogHelper.log('_mediaDir: $_mediaDir');
      LogHelper.log('_currentIndex: $_currentIndex');
      LogHelper.log('_sqlitePath: $_sqlitePath');
      LogHelper.log('_deckVersion: $_deckVersion');
      return;
    }

    final noteId = _noteIds[_currentIndex];
    
    // 先获取调度信息
    var scheduling = await AppDb.getCardScheduling(noteId);
    if (scheduling == null) {
      // 如果没有调度参数，创建默认值
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      scheduling = CardScheduling(
        cardId: noteId,
        stability: 0.0, // 新卡片从0开始
        difficulty: 5.0,
        due: now,
      );
      await AppDb.upsertCardScheduling(scheduling);
    }
    
    final result = await getDeckNote(sqlitePath: _sqlitePath!, noteId: noteId, version: _deckVersion!);
    
    setState(() {
      _selectedIndex = null;
      _showAnswer = false;
      _currentNote = result.note;
      _currentNotetype = result.notetype;
      _currentFields = result.fields;
      _currentCardOrd = result.ord;
      _currentQfmt = null;
      _currentAfmt = null;
      _currentConfig = result.css;
      _currentFront = result.front;
      _currentBack = result.back;
      _showBack = false;
      _currentScheduling = scheduling; // 使用获取到的调度信息
    });

    if (_currentNotetype == null || _currentNote == null) return;
    
    final fieldsForType = List<FieldExt>.from(_currentFields)..sort((a, b) => a.ord.compareTo(b.ord));
    final fieldMap = <String, String>{};
    for (int i = 0; i < fieldsForType.length && i < _currentNote!.flds.length; i++) {
      fieldMap[fieldsForType[i].name] = _currentNote!.flds[i];
    }
    final (frontPath, backPath) = await AnkiTemplateRenderer.renderFrontBackHtml(
      front: _currentFront ?? '',
      back: _currentBack ?? '',
      config: _currentConfig ?? '',
      fieldMap: fieldMap,
      js: null,
      mediaDir: _mediaDir,
      minFontSize: _minFontSize,
      deckId: widget.deckId,
    );
    _frontHtmlPath = frontPath;
    _backHtmlPath = backPath;
    LogHelper.log('设置HTML路径 - 正面: $frontPath, 反面: $backPath');
    // 直接加载正面 HTML
    _controller.loadRequest(Uri.parse('file://$frontPath'));
  }

  void _nextCard() {
    if (_noteIds.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _noteIds.length;
    });
    _saveProgress(_currentIndex);
    _loadCurrentCard();
  }

  void _prevCard() {
    if (_noteIds.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _noteIds.length) % _noteIds.length;
    });
    _saveProgress(_currentIndex);
    _loadCurrentCard();
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
              rating: value, // 直接使用 value，因为我们已经修正了按钮值
              now: now,
            )
          : await updateCardSchedule(
              stability: scheduling.stability,
              difficulty: scheduling.difficulty,
              lastReview: scheduling.due,
              rating: value, // 直接使用 value，因为我们已经修正了按钮值
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
        _nextCard();
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
        title: Text('刷卡 ( ${_currentIndex + 1}/${_noteIds.length})'),
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
          // 添加调度信息显示
          if (!_showBack) _buildSchedulingInfo(),
          Expanded(
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
                    if (_showBack && _currentNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 0, left: 16, right: 16, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFeedbackButton('😫', '困难', 0), // 改为 0 (Again)
                  const SizedBox(width: 12),
                  _buildFeedbackButton('😐', '一般', 1), // 改为 1 (Hard)
                  const SizedBox(width: 12),
                  _buildFeedbackButton('😄', '简单', 2), // 改为 2 (Good)
                ],
              ),
            ),
          Padding(
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
                    if (_showBack) {
                      _pendingShow = 'front';
                    } else {
                      _pendingShow = 'back';
                    }
                    await _controller.runJavaScript('trigger_save()');
                    // 不直接切页面，等 onMessageReceived 回调
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
        ],
      ),
    );
  }
} 