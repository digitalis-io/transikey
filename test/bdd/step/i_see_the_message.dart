import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the message {'Signed in'}
Future<void> iSeeTheMessage(WidgetTester tester, String message) async {
  expect(find.text(message), findsWidgets);
}
