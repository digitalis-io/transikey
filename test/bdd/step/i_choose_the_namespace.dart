import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose the namespace {'team-b'}
///
/// From the list that opens under the namespace field.
Future<void> iChooseTheNamespace(WidgetTester tester, String namespace) async {
  await tester.tap(find.widgetWithText(TextField, 'Namespace'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MenuItemButton, namespace));
  await tester.pumpAndSettle();
}
