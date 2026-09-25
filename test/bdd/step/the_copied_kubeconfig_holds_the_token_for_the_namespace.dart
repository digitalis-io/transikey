import 'package:flutter_test/flutter_test.dart';

import 'kubernetes_world.dart';

/// Usage: the copied kubeconfig holds the token for the namespace {'team-a'}
Future<void> theCopiedKubeconfigHoldsTheTokenForTheNamespace(
  WidgetTester tester,
  String namespace,
) async {
  final kubeconfig = KubernetesWorld.clipboard.copies.last;
  expect(kubeconfig, contains('token: "k8s-token-developer"'));
  expect(kubeconfig, contains('namespace: "$namespace"'));
}
