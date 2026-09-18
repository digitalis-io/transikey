import 'package:flutter_test/flutter_test.dart';

/// Usage: I do not see the message {'Signed in'}
Future<void> iDoNotSeeTheMessage(WidgetTester tester, String message) async {
  expect(find.text(message), findsNothing);
}
