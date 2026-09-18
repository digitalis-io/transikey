import 'package:flutter_test/flutter_test.dart';

Future<void> iDoNotSeeTheText(WidgetTester tester, String label) async {
  expect(find.text(label), findsNothing);
}
