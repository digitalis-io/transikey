import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I cannot request a Kubernetes token
Future<void> iCannotRequestAKubernetesToken(WidgetTester tester) async {
  final button = tester.widget<ButtonStyleButton>(
    find.ancestor(
      of: find.textContaining('Request token for'),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
  );
  expect(button.onPressed, isNull);
}
