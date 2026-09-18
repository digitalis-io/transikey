import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Stops one out-of-sync key event from blocking the keyboard for good.
///
/// Flutter buffers key events until the matching raw key message arrives and
/// empties the buffer only when dispatching succeeds. A key-down for a key
/// the framework believes is already pressed fails a debug assertion, stays
/// in the buffer and fails every later key press as well. Dropping the
/// buffer lets the next key-up clear the stale key, so typing recovers.
///
/// Assertions are off in release builds, where this is a no-op.
void installKeyEventRecovery() {
  if (!kDebugMode) return;
  // ignore: deprecated_member_use
  final manager = ServicesBinding.instance.keyEventManager;
  SystemChannels.keyEvent.setMessageHandler((message) async {
    try {
      // The framework registers this same handler; there is no replacement.
      // ignore: deprecated_member_use
      return await manager.handleRawKeyMessage(message);
    } catch (_) {
      // The only way to empty the buffer; debug-only, like this handler.
      // ignore: invalid_use_of_visible_for_testing_member
      manager.clearState();
      rethrow;
    }
  });
}
