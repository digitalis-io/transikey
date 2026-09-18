import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I pick the server {'prod'}
Future<void> iPickTheServer(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<String?>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}
