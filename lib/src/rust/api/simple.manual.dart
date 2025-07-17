import '../frb_generated.dart';
import 'dart:async';

final rustLogStream = StreamController<String>.broadcast();

void rustLogCallback(String msg) {
  print('[RUST] $msg');
  rustLogStream.add(msg);
}

Future<void> initRustLog() async {
  RustLib.instance.api.crateApiSimpleRegisterLogCallback().listen(
    rustLogCallback,
  );
}
