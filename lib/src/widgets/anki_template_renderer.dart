// Anki 模板渲染器，支持 anki2/anki21b 的模板渲染（字段映射、FrontSide、样式/JS 注入、区域语法等）
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

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

  /// 渲染正面
  String renderFront({String? deckId}) {
    return _wrapHtml(_render(front, null), true, deckId: deckId);
  }

  /// 渲染反面，支持 {{FrontSide}}
  String renderBack(String? frontHtml, {String? deckId}) {
    return _wrapHtml(_render(back, frontHtml), false, deckId: deckId);
  }

  static String _cleanHtml(String input) {
        // 从前往后，删除字符，直到碰到第一个字母、汉字、数字，<，>
        input = input.replaceFirst(RegExp(r'^[^a-zA-Z0-9\u4e00-\u9fa5<>{}]+'), '');
        // 从后往前，删除字符，直到碰到第一个字母、汉字、数字，<，>
        input = input.replaceFirst(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5<>{}]+$'), '');
        return input;
  }

  static String cleanConfigBlock(String input) {
        // 从前往后，删除字符，直到碰到第一个字母、汉字、数字，<，>
        input = input.replaceFirst(RegExp(r'^[^a-zA-Z0-9\u4e00-\u9fa5<>{}]+'), '');
        // 从后往前，删除字符，直到碰到第一个字母、汉字、数字，<，>
        input = input.replaceFirst(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5<>{}]+$'), '');
        return input;
  }

  /// 包裹完整HTML结构
  String _wrapHtml(String body, bool fullHeight, {String? deckId}) {
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
    
    final deckPrefix = deckId != null ? 'anki_${deckId}_' : 'anki_';
    
    // 变量检测脚本
    final beforeVarsScript = '''<script>
(function() {
  var before = Object.keys(window);
  window._ankiVarsBefore = before;
})();</script>''';

    // 变量检测和设置脚本
    final afterVarsScript = '''<script>
(function() {
  var before = window._ankiVarsBefore || [];
  var after = Object.keys(window);
  var newVars = after.filter(function(k){
    return !before.includes(k) && k != '_ankiVarsBefore' && typeof window[k] !== 'function';
  });
  window.sharedVarNames = newVars;
  ankiDebug('开始检测新增变量');
  ankiDebug('检测前变量数量: ' + before.length);
  ankiDebug('检测后变量数量: ' + after.length);
  ankiDebug('新增变量: ' + JSON.stringify(newVars));
})();</script>''';

    // 注入全局JS错误捕获
    final errorCatcherScript = '''<script>
window.onerror = function(message, source, lineno, colno, error) {
  if (window.AnkiDebug) {
    window.AnkiDebug.postMessage('[JS ERROR] ' + message + ' at ' + source + ':' + lineno + ':' + colno);
  }
};
</script>''';

    // localStorage脚本
    final localStorageScript = '''<script>
// 创建深度代理函数
function createDeepProxy(obj, deckPrefix, varName) {
  if (obj === null || typeof obj !== 'object') return obj;
  if (obj.__isProxied) return obj; // 防止重复代理

  // 批量保存机制
  let saveScheduled = false;
  function scheduleSave(deckPrefix, varName) {
    if (saveScheduled) return;
    saveScheduled = true;
    setTimeout(() => {
      saveScheduled = false;
      try {
        localStorage.setItem(deckPrefix + varName, JSON.stringify(window[varName]));
        if (typeof ankiDebug === 'function') {
          ankiDebug('批量保存 ' + varName + ' 到 localStorage');
        }
        if (window.AnkiSave) {
          window.AnkiSave.postMessage('saved');
        }
      } catch (e) {
        if (typeof ankiDebug === 'function') {
          ankiDebug('保存到 localStorage 失败: ' + e);
        }
      }
    }, 0);
  }

  const handler = {
    get(target, prop, receiver) {
      const value = Reflect.get(target, prop, receiver);
      if (typeof value === 'object' && value !== null && !value.__isProxied) {
        const proxied = createDeepProxy(value, deckPrefix, varName + '.' + prop);
        target[prop] = proxied;
        return proxied;
      }
      return value;
    },
    set(target, prop, value, receiver) {
      const result = Reflect.set(target, prop, value, receiver);
      ankiDebug('Proxy set: ' + varName + '.' + String(prop) + ' = ' + JSON.stringify(value));
      scheduleSave(deckPrefix, varName);
      return result;
    }
  };
  Object.defineProperty(obj, '__isProxied', { value: true, enumerable: false });
  return new Proxy(obj, handler);
}

// 手动保存函数
function saveToLocalStorage(deckPrefix) {
  if (window.sharedVarNames) {
    window.sharedVarNames.forEach(function(varName) {
      const value = window[varName];
      if (value !== undefined && value !== null) {
        localStorage.setItem(deckPrefix + varName, JSON.stringify(value));
        function ankiDebug(msg) {
          if (window.AnkiDebug) {
            window.AnkiDebug.postMessage(msg);
          }
        }
        ankiDebug('手动保存变量 ' + varName + ' 到localStorage');
      }
    });
  }
}

// 页面加载时恢复变量并设置监听
(function() {
  var deckPrefix = '$deckPrefix';
  function ankiDebug(msg) {
    if (window.AnkiDebug) {
      window.AnkiDebug.postMessage(msg);
    }
  }
  ankiDebug('开始恢复变量, deckPrefix: ' + deckPrefix);
  
  // 先恢复变量
  if (window.sharedVarNames) {
    window.sharedVarNames.forEach(function(varName) {
      const saved = localStorage.getItem(deckPrefix + varName);
      if (saved) {
        try {
          const restoredValue = JSON.parse(saved);
          window[varName] = restoredValue;
          ankiDebug('恢复变量 ' + varName + ' = ' + JSON.stringify(window[varName]));
        } catch(e) {
          window[varName] = saved;
          ankiDebug('恢复变量 ' + varName + ' = ' + window[varName] + ' (字符串)');
        }
      } else {
        ankiDebug('变量 ' + varName + ' 在localStorage中不存在');
      }
    });
  }
  
  // 然后设置变量监听
  ankiDebug('开始设置变量监听, deckPrefix: ' + deckPrefix);
  if (window.sharedVarNames) {
    window.sharedVarNames.forEach(function(varName) {
      let currentValue = window[varName];
      ankiDebug('检查变量 ' + varName + ', 类型: ' + typeof currentValue);
      
      // 使用 Proxy 深度监听对象
      if (typeof currentValue == 'object' && currentValue !== null) {
        window[varName] = createDeepProxy(currentValue, deckPrefix, varName);
        ankiDebug('已设置对象变量 ' + varName + ' 的深度监听器');
      }
    });
  }
})();
</script>''';

    // 注入哨兵变量，这个值的变化将会触发deep proxy，然后触发ankisave，然后切换页面
    final sentinelScript = '''<script>
window.anki_save_sentinel = {"current": Date.now()};

function trigger_save() {
  type = typeof anki_save_sentinel;
  ankiDebug("trigger save called, anki_save_sentinel prev: " + anki_save_sentinel + ", type:" + type);
  window.anki_save_sentinel.current = Date.now();
}
</script>''';

    // 清理configBlock
    final safeConfigBlock = cleanConfigBlock(configBlock);
    final height = fullHeight ? 'style="height:100%"' : '';

    return '''
<!DOCTYPE html>
<html $height>
<head>
  <!-- 公共 -->
  <script>
  function ankiDebug(msg) {
    if (window.AnkiDebug) {
      window.AnkiDebug.postMessage(msg);
    }
  }
  </script>
  <meta charset="utf-8">
  <!-- beforeVarsScript -->
  $beforeVarsScript

  <!-- sentinelScript -->
  $sentinelScript

  <!-- fallbackFontCss -->
  $fallbackFontCss

  <!-- errorCatcherScript -->
  $errorCatcherScript

  <!-- configBlock -->
  $safeConfigBlock

  <!-- script -->
  $script

  <!-- afterVarsScript -->
  $afterVarsScript

  <!-- localStorageScript -->
  $localStorageScript
</head>
<body style="height:100%">
<div class="card card1 card2" style="height:100%;padding:20px">
$body
</div>
</body>
</html>
''';
  }

  String _addImageSupport(String html) {
    if (mediaDir == null) return html;
    // 匹配 <img src="xxx">，不处理已是绝对路径或以 http(s) 开头的
    final reg1 = RegExp(r'<img\s+[^>]*src=["](?!https?://|/)([^">]+)["][^>]*>', caseSensitive: false);
    final reg2 = RegExp(r"<img\s+[^>]*src=['](?!https?://|/)([^'>]+)['][^>]*>", caseSensitive: false);

    String _replaceImgSrc(Match m) {
      final src = m.group(1)!;
      final newTag = m[0]!.replaceFirst(src, '${mediaDir!}/$src');
      return newTag;
    }

    var result = html.replaceAllMapped(reg1, _replaceImgSrc);
    result = result.replaceAllMapped(reg2, _replaceImgSrc);
    return result;
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
    html = _addAudioSupport(html);
    html = _addImageSupport(html);
    return html;
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

   static void printLongHtml(String html) {
      // Flutter 的 print 会截断超长字符串，这里分段输出
      const int chunkSize = 800;
      for (int i = 0; i < html.length; i += chunkSize) {
        final end = (i + chunkSize < html.length) ? i + chunkSize : html.length;
        print(html.substring(i, end));
      }
    }

  /// 写入正反面HTML到本地文件，并返回主页面HTML和文件路径
  static Future<(String frontPath, String backPath)> renderFrontBackHtml({
    required String front,
    required String back,
    required String config,
    required Map<String, String> fieldMap,
    String? js,
    String? mediaDir,
    double minFontSize = 18,
    String? deckId,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final frontPath = '${dir.path}/anki_front_$timestamp.html';
    final backPath = '${dir.path}/anki_back_$timestamp.html';
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
    String frontHtml = renderer.renderFront(deckId: deckId);
    String backHtml = renderer.renderBack(front, deckId: deckId);
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

  /// Checks if the card's templates (front, back, css/js) might connect to the network.
  static bool cardMightConnectToNetwork({
    required String front,
    required String back,
    required String config,
  }) {
    // Combine all template parts into a single string for checking.
    final combinedContent = '$front $back $config';
    
    // A simple regex to detect http:// or https:// URLs.
    final networkRegex = RegExp(r'https?://', caseSensitive: false);
    return networkRegex.hasMatch(combinedContent);
  }
} 