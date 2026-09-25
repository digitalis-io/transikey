import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I ask for a cluster-wide binding
Future<void> iAskForAClusterwideBinding(WidgetTester tester) async {
  await tester.tap(
    find.widgetWithText(CheckboxListTile, 'Cluster-wide binding'),
  );
  await tester.pumpAndSettle();
}
