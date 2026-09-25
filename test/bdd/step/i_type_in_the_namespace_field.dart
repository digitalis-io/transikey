import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I type {'b'} in the namespace field
///
/// Filters the list without adding anything.
Future<void> iTypeInTheNamespaceField(WidgetTester tester, String text) async {
  await tester.enterText(find.widgetWithText(TextField, 'Namespaces'), text);
  await tester.pumpAndSettle();
}
