import 'package:flutter_test/flutter_test.dart';

/// Usage: I clear the credentials from the screen
Future<void> iClearTheCredentialsFromTheScreen(WidgetTester tester) async {
  final clear = find.text('Clear from screen');
  // The card is taller than the test window.
  await tester.ensureVisible(clear);
  await tester.tap(clear);
  await tester.pumpAndSettle();
}
