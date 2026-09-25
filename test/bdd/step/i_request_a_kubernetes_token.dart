import 'package:flutter_test/flutter_test.dart';

/// Usage: I request a Kubernetes token
Future<void> iRequestAKubernetesToken(WidgetTester tester) async {
  await tester.tap(find.textContaining('Request token for'));
  await tester.pumpAndSettle();
}
