// Anki 模板渲染器，支持 anki2/anki21b 的模板渲染（字段映射、FrontSide、样式/JS 注入、区域语法等）
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AnkiTemplateRenderer {
  final String front;
  final String back;
  final String? config;
  final Map<String, String> fieldMap;
  final String? js;
  final String? mediaDir;
  final double minFontSize;
  final bool mergeFrontBack;

  AnkiTemplateRenderer({
    required String front,
    required String back,
    required this.fieldMap,
    String? config,
    this.js,
    this.mediaDir,
    this.minFontSize = 18,
    this.mergeFrontBack = false,
  })  : front = _cleanHtml(front),
        back = _cleanHtml(back),
        config = config != null ? _cleanHtml(config) : null;

  static String _cleanHtml(String input) {
    // 去除 BOM、不可见控制字符（保留常用换行/制表符）
    return input
        .replaceAll('  ', '') // BOM
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // 控制字符
        .replaceAll('  ', '') // 垂直制表符
        .replaceAll('  ', '') // 换页符
        ;
  }

  /// 包裹完整HTML结构
  String _wrapHtml(String body, {String? extraHead}) {
    final fallbackFontCss = '''
<style>
body, .card, .text, .cloze, .wrong, .classify, .remark, .options, .options * {
  font-size: min(max(1em, ${minFontSize.toInt()}px), 100vw);
}
</style>
''';
    String configBlock = '';
    if (config != null && config!.trim().isNotEmpty) {
      if (config!.contains('<style')) {
        configBlock = config!;
      } else {
        configBlock = '<style>\n${config!}\n</style>';
      }
    }
    final script = js != null && js!.trim().isNotEmpty ? '<script>\n${js!}\n</script>' : '';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  $fallbackFontCss
  $configBlock
  $script
  ${extraHead ?? ''}
</head>
<body>
$body
</body>
</html>
''';
  }

  /// 渲染正面
  String renderFront() {
    return _wrapHtml(_render(front, null));
  }

  /// 渲染反面，支持 {{FrontSide}}
  String renderBack(String? frontHtml) {
    return _wrapHtml(_render(back, frontHtml));
  }

  /// 主渲染逻辑，返回内容片段
  String _render(String template, String? frontHtml) {
    String html = template;
    // 1. 处理 {{FrontSide}}
    if (frontHtml != null) {
      html = html.replaceAll('{{FrontSide}}', frontHtml);
    }
    // 2. 处理 {{字段}} 和 {{text:字段}}
    fieldMap.forEach((k, v) {
      html = html.replaceAll('{{$k}}', v);
      html = html.replaceAll('{{text:$k}}', v);
    });
    // 3. 处理 {{#区域}}...{{/区域}}（简单实现：有值就保留，无值就去掉）
    final reg = RegExp(r'{{#(\w+)}}([\s\S]*?){{/\1}}');
    html = html.replaceAllMapped(reg, (m) {
      final key = m.group(1)!;
      final content = m.group(2)!;
      if (fieldMap[key]?.isNotEmpty == true) {
        return content;
      } else {
        return '';
      }
    });
    return _addAudioSupport(html);
  }

  String _addAudioSupport(String html) {
    if (mediaDir == null) return html;
    final reg = RegExp(r'\[sound:([\w\d\-_\.]+)\]');
    return html.replaceAllMapped(reg, (m) {
      final file = m.group(1)!;
      final audioId = 'audio_${file.hashCode}';
      
      return '''
<span style="cursor:pointer;vertical-align:middle;" onclick="var a=document.getElementById('$audioId');a.currentTime=0;a.play();">
  <svg width="48" height="48" viewBox="0 0 24 24" fill="#666"><path d="M3 10v4h4l5 5V5L7 10H3zm13.5 2c0-1.77-1.02-3.29-2.5-4.03v8.06c1.48-.74 2.5-2.26 2.5-4.03z"/></svg>
</span>
<audio id="$audioId" src="${mediaDir!}/$file" style="display:none"></audio>
''';

    });
  }

  /// 合并正反面渲染，推荐用writeMergedToFiles+composeIframeHtml，renderMerged仅保留兼容性（不再包含iframe结构）。
  String renderMerged({String? frontHtml}) {
    // 兼容性保留：直接渲染正反面内容到同一div，不再包含iframe结构
    final frontContent = _render(front, null);
    final backContent = _render(back, frontHtml ?? frontContent);
    final toggleScript = '''
<script>
function showFront() {
  document.getElementById('anki-main').innerHTML = window.ankiFrontHtml;
}
function showBack() {
  document.getElementById('anki-main').innerHTML = window.ankiBackHtml;
}
window.onload = function() { showFront(); };
</script>
''';
    final body = '<div id="anki-main"></div>';
    return _wrapHtml(body, extraHead: toggleScript);
  }

   static void printLongHtml(String html) {
      // Flutter 的 print 会截断超长字符串，这里分段输出
      const int chunkSize = 800;
      for (int i = 0; i < html.length; i += chunkSize) {
        final end = (i + chunkSize < html.length) ? i + chunkSize : html.length;
        print(html.substring(i, end));
      }
    }

  /// 写入正反面HTML到本地文件，并返回主页面HTML和文件路径
  static Future<(String frontPath, String backPath)> writeMergedToFiles({
    required String front,
    required String back,
    required String config,
    required Map<String, String> fieldMap,
    String? js,
    String? mediaDir,
    double minFontSize = 18,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final frontPath = '${dir.path}/anki_front.html';
    final backPath = '${dir.path}/anki_back.html';
    final renderer = AnkiTemplateRenderer(
      front: front,
      back: back,
      config: config,
      fieldMap: fieldMap,
      js: js,
      mediaDir: mediaDir,
      minFontSize: minFontSize,
      mergeFrontBack: false,
    );
    String frontHtml = renderer.renderFront();
    String backHtml = renderer.renderBack(renderer.renderFront());
    // 调试：如内容为空则写入简单内容
    if (frontHtml.trim().isEmpty) {
      frontHtml = '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body><h1>Front</h1></body></html>';
    }
    if (backHtml.trim().isEmpty) {
      backHtml = '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body><h1>Back</h1></body></html>';
    }
    await File(frontPath).writeAsString(frontHtml);
    await File(backPath).writeAsString(backHtml);
    printLongHtml('Anki frontHtml path: $frontPath');
    printLongHtml('Anki backHtml path: $backPath');
    printLongHtml('Anki frontHtml content:\n$frontHtml');
    printLongHtml('Anki backHtml content:\n$backHtml');
    
    return (frontPath, backPath);
  }

  /// 生成iframe主页面HTML
  static String composeIframeHtml(String frontPath, String backPath, String testHtmlPath) {
    final frontUrl = 'file://$frontPath';
    final backUrl = 'file://$backPath';
    final testUrl = 'file://$testHtmlPath';
    final frontFile = File(frontPath);
    final backFile = File(backPath);
    final testFile = File(testHtmlPath);
    final frontExists = frontFile.existsSync();
    final backExists = backFile.existsSync();
    final testExists = testFile.existsSync();
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>body,html{margin:0;padding:0;}</style>
  <script>
    function showFront() {
      document.getElementById('anki-front-frame').style.display = 'block';
      document.getElementById('anki-back-frame').style.display = 'none';
      if(document.getElementById('test-frame')) document.getElementById('test-frame').style.display = 'block';
    }
    function showBack() {
      document.getElementById('anki-front-frame').style.display = 'none';
      document.getElementById('anki-back-frame').style.display = 'block';
      if(document.getElementById('test-frame')) document.getElementById('test-frame').style.display = 'block';
    }
    window.onload = function() { showFront(); };
    window.onerror = function(e) { document.body.innerHTML = 'JS ERROR: ' + e; }
  </script>
</head>
<body style="margin:0;padding:0;">
  <!--
      $frontUrl $frontExists<br />
      $backUrl $backExists<br />
      $testUrl $testExists<br />
  -->
  <iframe id="anki-front-frame" src="$frontUrl" style="width:100vw;height:40vh;border:2px solid #888;display:block" sandbox="allow-scripts allow-same-origin"></iframe>
  <iframe id="anki-back-frame" src="$backUrl" style="width:100vw;height:40vh;border:2px solid #888;display:none" sandbox="allow-scripts allow-same-origin"></iframe>
  <!--
      <iframe id="test-frame" src="$testUrl" style="width:100vw;height:20vh;border:2px solid #f00;display:block" sandbox="allow-scripts allow-same-origin"></iframe>
  -->
</body>
</html>
''';
  }
} 