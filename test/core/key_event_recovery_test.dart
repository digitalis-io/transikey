// The simulator still needs the deprecated transit mode to mimic macOS.
// ignore_for_file: deprecated_member_use

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/utils/key_event_recovery.dart';

void main() {
  // Flutter buffers key events until the raw key message arrives and only
  // empties the buffer when dispatching succeeds. A key-down for a key the
  // framework already believes is pressed fails a debug assertion, stays in
  // the buffer and fails every later key press too.
  testWidgets('typing works again after an out-of-sync key-down', (
    tester,
  ) async {
    debugKeyEventSimulatorTransitModeOverride =
        KeyDataTransitMode.keyDataThenRawKeyData;
    installKeyEventRecovery();

    // The engine reports Backspace as held although its key-up was seen.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.keyboard,
      (call) async => {
        PhysicalKeyboardKey.backspace.usbHidUsage:
            LogicalKeyboardKey.backspace.keyId,
      },
    );
    await HardwareKeyboard.instance.syncKeyboardState();

    final seen = <KeyEvent>[];
    bool record(KeyEvent event) {
      seen.add(event);
      return false;
    }

    HardwareKeyboard.instance.addHandler(record);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(record));

    Object? error;
    try {
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.backspace,
        platform: 'macos',
      );
    } catch (e) {
      error = e;
    }
    expect(error, isAssertionError);
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.backspace,
      platform: 'macos',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA, platform: 'macos');
    expect(
      seen.whereType<KeyDownEvent>().map((e) => e.logicalKey),
      contains(LogicalKeyboardKey.keyA),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA, platform: 'macos');
    // The binding checks debug variables before tear-downs run.
    debugKeyEventSimulatorTransitModeOverride = null;
  });
}
