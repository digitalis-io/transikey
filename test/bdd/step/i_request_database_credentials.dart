import 'package:flutter_test/flutter_test.dart';

/// Usage: I request database credentials
Future<void> iRequestDatabaseCredentials(WidgetTester tester) async {
  await tester.tap(find.textContaining('Request credentials for'));
  await tester.pumpAndSettle();
}
