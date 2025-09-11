import 'package:flutter/foundation.dart';

String _ts() => DateTime.now().toIso8601String();

void logv(String tag, String message) {
  if (kDebugMode) {
    debugPrint('[${_ts()}][$tag] $message');
  }
}

