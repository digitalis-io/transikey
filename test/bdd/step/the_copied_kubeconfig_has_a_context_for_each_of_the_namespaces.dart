import 'package:flutter_test/flutter_test.dart';

import 'kubernetes_world.dart';

/// Usage: the copied kubeconfig has a context for each of the namespaces {'team-a, team-b'}
Future<void> theCopiedKubeconfigHasAContextForEachOfTheNamespaces(
  WidgetTester tester,
  String namespaces,
) async {
  final kubeconfig = KubernetesWorld.clipboard.copies.last;
  for (final ns in namespaces.split(',').map((n) => n.trim())) {
    expect(kubeconfig, contains('name: "transikey-kubernetes-developer-$ns"'));
    expect(kubeconfig, contains('namespace: "$ns"'));
  }
}
