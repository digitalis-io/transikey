import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the unwrap form targets the server {'https://bao.partner.example:8200'}
Future<void> theUnwrapFormTargetsTheServer(
  WidgetTester tester,
  String address,
) async {
  final field = tester.widget<TextField>(
    find.widgetWithText(TextField, 'Server (optional)'),
  );
  expect(field.controller!.text, address);
  final token = tester.widget<TextField>(
    find.widgetWithText(TextField, 'Wrapping token'),
  );
  expect(token.controller!.text, isNotEmpty);
  expect(token.obscureText, isTrue);
}
