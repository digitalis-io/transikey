import 'package:flutter_test/flutter_test.dart';

/// Usage: I import the CLI environment
Future<void> iImportTheCliEnvironment(WidgetTester tester) async {
  await tester.tap(find.textContaining('Import from CLI'));
  await tester.pumpAndSettle();
}
