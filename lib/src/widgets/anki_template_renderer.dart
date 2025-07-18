// Anki 模板渲染器，支持 anki2/anki21b 的模板渲染（字段映射、FrontSide、样式/JS 注入、区域语法等）
import 'dart:convert';
import 'package:flutter/foundation.dart';

class AnkiTemplateRenderer {
  final String front;
  final String back;
  final String? css;
  final Map<String, String> fieldMap;
  final String? js;

  AnkiTemplateRenderer({
    required this.front,
    required this.back,
    required this.fieldMap,
    this.css,
    this.js,
  });

  /// 渲染正面
  String renderFront() {
    return _render(front, null);
  }

  /// 渲染反面，支持 {{FrontSide}}
  String renderBack(String? frontHtml) {
    return _render(back, frontHtml);
  }

  /// 主渲染逻辑
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
    // 4. 注入样式和 JS
    final style = css != null && css!.trim().isNotEmpty ? '<style>\n${css!}\n</style>' : '';
    final script = js != null && js!.trim().isNotEmpty ? '<script>\n${js!}\n</script>' : '';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  $style
  $script
  <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
</head>
<body>
$html
</body>
</html>
''';
  }
} 