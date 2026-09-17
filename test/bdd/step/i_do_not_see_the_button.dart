import 'package:flutter_test/flutter_test.dart';

Future<void> iDoNotSeeTheButton(WidgetTester tester, String label) async {
  expect(find.text(label), findsNothing);
}
