import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose the namespace {'team-b'}
Future<void> iChooseTheNamespace(WidgetTester tester, String namespace) async {
  await tester.tap(find.widgetWithText(ChoiceChip, namespace));
  await tester.pumpAndSettle();
}
