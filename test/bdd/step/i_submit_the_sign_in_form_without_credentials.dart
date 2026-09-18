import 'package:flutter_test/flutter_test.dart';

/// Usage: I submit the sign in form without credentials
Future<void> iSubmitTheSignInFormWithoutCredentials(WidgetTester tester) async {
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}
