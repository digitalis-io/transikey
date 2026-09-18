import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I sign in with userpass as {'demo'} and password {'good-password'}
Future<void> iSignInWithUserpassAsAndPassword(
  WidgetTester tester,
  String username,
  String password,
) async {
  await tester.tap(find.text('Userpass'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Username'),
    username,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}
