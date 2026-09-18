import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the sign in form targets {'https://bao.prod.example:8200'} as {'sergio'}
Future<void> theSignInFormTargetsAs(
  WidgetTester tester,
  String address,
  String username,
) async {
  String textOf(String label) => tester
      .widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, label),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  expect(textOf('Vault / OpenBao address'), address);
  if (username.isNotEmpty) {
    // Remembered method (LDAP) shows the username field.
    expect(textOf('Username'), username);
  }
}
