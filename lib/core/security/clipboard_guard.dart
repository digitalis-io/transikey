import 'dart:async';

import 'package:flutter/services.dart';

/// Copies secrets to the clipboard and clears them after a timeout, unless
/// the user has copied something else in the meantime.
class ClipboardGuard {
  ClipboardGuard({Duration Function()? timeout})
    : _timeout = timeout ?? (() => const Duration(seconds: 30));

  final Duration Function() _timeout;
  Timer? _timer;
  String? _pending;

  Future<void> copy(String value) async {
    _timer?.cancel();
    _pending = value;
    await Clipboard.setData(ClipboardData(text: value));
    final timeout = _timeout();
    if (timeout > Duration.zero) _timer = Timer(timeout, clearIfOurs);
  }

  /// Clears the clipboard only when it still holds the value we put there.
  Future<void> clearIfOurs() async {
    final pending = _pending;
    _timer?.cancel();
    _pending = null;
    if (pending == null) return;
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == pending) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  void dispose() {
    _timer?.cancel();
    _pending = null;
  }
}
