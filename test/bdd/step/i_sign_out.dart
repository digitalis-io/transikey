import 'package:flutter_test/flutter_test.dart';

/// Usage: I sign out
Future<void> iSignOut(WidgetTester tester) async {
  await tester.tap(find.text('Sign out'));
  await tester.pumpAndSettle();
}
