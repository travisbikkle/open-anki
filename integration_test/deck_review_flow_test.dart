import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:open_anki/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('完整刷卡流程测试：导入->刷卡->验证进度->删除', (WidgetTester tester) async {
    // 0. 清理环境，确保从干净状态开始
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'anki_index.db'));
    final deckDir = Directory(join(dir.path, 'anki_data'));

    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    if (await deckDir.exists()) {
      await deckDir.delete(recursive: true);
    }

    // 1. 准备环境：复制牌组文件
    final data = await rootBundle.load('assets/anki21b.apkg');
    final file = File('${dir.path}/anki21b.apkg');
    await file.writeAsBytes(data.buffer.asUint8List());

    // 2. 启动并导入
    app.main();
    await tester.pumpAndSettle();

    final deckNavBtn = find.text('题库');
    expect(deckNavBtn, findsOneWidget);
    await tester.tap(deckNavBtn);
    await tester.pumpAndSettle();

    final autoImportBtn = find.byKey(const Key('auto_import_button'));
    expect(autoImportBtn, findsOneWidget);
    await tester.tap(autoImportBtn);
    
    // 等待转圈出现
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    
    // 等待转圈消失，表示导入完成
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    
    // 导入成功后再查找牌组
    expect(find.text('anki21b'), findsWidgets);
    
    // 3. 进入刷卡
    print("进入刷卡");
    final deckTile = find.text('anki21b');
    expect(deckTile, findsWidgets);
    await tester.tap(deckTile.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 3000));

    print("答案");
    // 4. 模拟刷卡
    // 点击“显示答案”按钮
    final showAnswerBtn = find.text('答案');
    expect(showAnswerBtn, findsOneWidget);
    await tester.tap(showAnswerBtn);
    await tester.pumpAndSettle(const Duration(milliseconds: 3000));

    print("后退");
    final backBtn = find.byIcon(Icons.arrow_back);
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle(const Duration(milliseconds: 3000));
    
    // 验证进度条更新，查找文本“1/X”
    expect(find.textContaining(RegExp(r'1/\d+')), findsOneWidget);
    
    // 6. 清理环境：删除牌组
    final deckToDelete = find.text('anki21b');
    expect(deckToDelete, findsWidgets);
    await tester.longPress(deckToDelete.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 1000));

    print("删除");
    final deleteBtn = find.text('删除');
    expect(deleteBtn, findsOneWidget);
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();

    final confirmBtn = find.text('删除').last;
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(find.text('anki21b'), findsNothing);
  });
} 