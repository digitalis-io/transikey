import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nothing_has_been_copied.dart';

/// Usage: I cannot copy the kubeconfig
Future<void> iCannotCopyTheKubeconfig(WidgetTester tester) async {
  final button = tester.widget<ButtonStyleButton>(
    find.ancestor(
      of: find.text('Copy kubeconfig'),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
  );
  expect(button.onPressed, isNull);
  await nothingHasBeenCopied(tester);
}
