import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the namespaces offered are {'team-a, team-b'}
Future<void> theNamespacesOfferedAre(WidgetTester tester, String names) async {
  final expected = names.split(',').map((n) => n.trim()).toList();
  if (!tester.any(find.byType(CheckboxMenuButton))) {
    await tester.tap(find.widgetWithText(TextField, 'Namespaces'));
    await tester.pumpAndSettle();
  }
  final offered = tester
      .widgetList<CheckboxMenuButton>(find.byType(CheckboxMenuButton))
      .map((b) => (b.child as Text?)?.data)
      .whereType<String>()
      .toList();
  expect(offered, expected);
}
