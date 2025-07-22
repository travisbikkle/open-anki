import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:open_anki/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('自动测试-导入并删除anki21牌组', (WidgetTester tester) async {
    // 准备测试数据：将assets/anki21.apkg写入应用文档目录
    final data = await rootBundle.load('assets/anki21.apkg');
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/anki21.apkg');
    await file.writeAsBytes(data.buffer.asUint8List());

    app.main();
    await tester.pumpAndSettle();

    // 先点击底部导航栏“题库”按钮，进入题库界面
    final deckNavBtn = find.text('题库');
    expect(deckNavBtn, findsOneWidget);
    await tester.tap(deckNavBtn);
    await tester.pumpAndSettle();

    // 触发自动导入隐藏按钮
    final autoImportBtn = find.byKey(const Key('auto_import_button'));
    expect(autoImportBtn, findsOneWidget);
    await tester.tap(autoImportBtn);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 检查导入成功提示
    expect(find.text('自动导入成功'), findsOneWidget);
    // 检查牌组列表中出现anki21
    expect(find.text('anki21'), findsWidgets);

    // 删除anki21牌组
    final deckTile = find.text('anki21');
    expect(deckTile, findsWidgets);
    await tester.longPress(deckTile.first);
    await tester.pumpAndSettle();
    final deleteBtn = find.text('删除');
    expect(deleteBtn, findsOneWidget);
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();
    final confirmBtn = find.text('删除').last;
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();
    expect(find.text('anki21'), findsNothing);
  });
} 