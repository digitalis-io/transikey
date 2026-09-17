import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I wrap the secret {'database password is hunter2'}
Future<void> iWrapTheSecret(WidgetTester tester, String secret) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Secret (text or JSON object)'),
    secret,
  );
  await tester.tap(find.text('Wrap secret'));
  await tester.pumpAndSettle();
}
