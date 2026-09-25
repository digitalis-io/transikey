import 'package:flutter_test/flutter_test.dart';

import 'kubernetes_world.dart';

/// Usage: the service account is bound cluster-wide
Future<void> theServiceAccountIsBoundClusterwide(WidgetTester tester) async {
  expect(KubernetesWorld.lastClusterRoleBinding, isTrue);
}
