import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

class LogHelper {
  static File? _logFile;
  static StreamController<String>? _logController;
  static Future<void>? _initFuture;

  static Future<void> init() async {
    if (_initFuture != null) return _initFuture;
    _initFuture = _init();
    return _initFuture;
  }

  static Future<void> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/open_anki.log');
    _logController = StreamController<String>();
    _logController!.stream.listen((msg) async {
      final now = DateTime.now().toIso8601String();
      await _logFile!.writeAsString('[$now] $msg\n', mode: FileMode.append);
    });
  }

  static void log(String message) {
    _logController?.add(message);
  }

  static Future<String> getRecentLog({int lines = 100}) async {
    if (_logFile == null || !await _logFile!.exists()) return '';
    final allLines = await _logFile!.readAsLines();
    return allLines.length > lines
        ? allLines.sublist(allLines.length - lines).join('\n')
        : allLines.join('\n');
  }

  static Future<void> dispose() async {
    await _logController?.close();
  }
} 