import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kubernetes_world.dart';

/// Usage: I cannot copy the kubeconfig
Future<void> iCannotCopyTheKubeconfig(WidgetTester tester) async {
  final button = tester.widget<ButtonStyleButton>(
    find.ancestor(
      of: find.text('Copy kubeconfig'),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
  );
  expect(button.onPressed, isNull);
  expect(KubernetesWorld.clipboard.copies, isEmpty);
}
