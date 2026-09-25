import 'package:flutter_test/flutter_test.dart';

/// Usage: I revoke the tokens
Future<void> iRevokeTheTokens(WidgetTester tester) async {
  final revoke = find.textContaining('Revoke');
  await tester.ensureVisible(revoke.last);
  await tester.tap(revoke.last);
  await tester.pumpAndSettle();
}
