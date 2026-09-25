import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I enter the namespace {'team-b'}
Future<void> iEnterTheNamespace(WidgetTester tester, String namespace) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Namespace'),
    namespace,
  );
  await tester.pumpAndSettle();
}
