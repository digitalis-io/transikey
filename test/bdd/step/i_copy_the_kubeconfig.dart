import 'package:flutter_test/flutter_test.dart';

/// Usage: I copy the kubeconfig
Future<void> iCopyTheKubeconfig(WidgetTester tester) async {
  final copy = find.text('Copy kubeconfig');
  await tester.ensureVisible(copy);
  await tester.tap(copy);
  await tester.pumpAndSettle();
}
