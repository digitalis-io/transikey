import 'package:flutter_test/flutter_test.dart';

Future<void> iSeeTheButton(WidgetTester tester, String label) async {
  expect(find.text(label), findsWidgets);
}
