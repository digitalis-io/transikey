import 'package:flutter_test/flutter_test.dart';

import 'kubernetes_world.dart';

/// Usage: the service account is bound within its namespace
Future<void> theServiceAccountIsBoundWithinItsNamespace(
  WidgetTester tester,
) async {
  expect(KubernetesWorld.lastClusterRoleBinding, isFalse);
}
