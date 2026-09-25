import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the namespace {'team-z'} is offered as used before
Future<void> theNamespaceIsOfferedAsUsedBefore(
  WidgetTester tester,
  String namespace,
) async {
  await tester.tap(find.widgetWithText(TextField, 'Namespace'));
  await tester.pumpAndSettle();
  expect(
    find.descendant(
      of: find.widgetWithText(MenuItemButton, namespace),
      matching: find.byIcon(Icons.history),
    ),
    findsOneWidget,
  );
}
