import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I pick the role {'readonly'}
Future<void> iPickTheRole(WidgetTester tester, String role) async {
  await tester.tap(find.widgetWithText(ListTile, role));
  await tester.pumpAndSettle();
}
