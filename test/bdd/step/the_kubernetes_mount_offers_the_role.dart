import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'kubernetes_world.dart';

/// Usage: the Kubernetes mount {'k8s-prod'} offers the role {'deployer'}
Future<void> theKubernetesMountOffersTheRole(
  WidgetTester tester,
  String mount,
  String role,
) async {
  KubernetesWorld.mounts[mount] = 'kubernetes';
  when(
    () => KubernetesWorld.server.listKubernetesRoles(mount),
  ).thenAnswer((_) async => [role]);
}
