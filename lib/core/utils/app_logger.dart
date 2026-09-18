import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'redaction.dart';

/// Application logger. Every message passes through [Redaction] so secrets
/// cannot leak even when a caller logs a raw server message.
class AppLogger {
  AppLogger({Logger? logger})
    : _logger =
          logger ??
          Logger(
            level: kReleaseMode ? Level.info : Level.debug,
            printer: SimplePrinter(colors: false, printTime: true),
          );

  final Logger _logger;

  void debug(String message, [Map<String, Object?>? fields]) =>
      _logger.d(_format(message, fields));

  void info(String message, [Map<String, Object?>? fields]) =>
      _logger.i(_format(message, fields));

  void warning(String message, [Map<String, Object?>? fields]) =>
      _logger.w(_format(message, fields));

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(
        Redaction.text(message),
        error: error == null ? null : Redaction.text(error.toString()),
        stackTrace: stackTrace,
      );

  String _format(String message, Map<String, Object?>? fields) {
    final safe = Redaction.text(message);
    if (fields == null || fields.isEmpty) return safe;
    return '$safe ${Redaction.value(fields)}';
  }
}
