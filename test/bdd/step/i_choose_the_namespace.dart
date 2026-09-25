import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose the namespace {'team-b'}
///
/// Ticks it in the list under the field, then closes the list.
Future<void> iChooseTheNamespace(WidgetTester tester, String namespace) async {
  await tester.tap(find.widgetWithText(TextField, 'Namespaces'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxMenuButton, namespace));
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}
