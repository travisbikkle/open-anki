import '../frb_generated.dart';
import 'dart:async';
import 'package:open_anki/src/log_helper.dart';

final rustLogStream = StreamController<String>.broadcast();

void rustLogCallback(String msg) {
  LogHelper.log('[RUST] $msg');
  rustLogStream.add(msg);
}

Future<void> initRustLog() async {
  RustLib.instance.api.crateApiSimpleRegisterLogCallback().listen(
    rustLogCallback,
  );
}
