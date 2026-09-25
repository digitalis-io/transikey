import 'package:flutter_test/flutter_test.dart';

import 'kubernetes_world.dart';

/// Usage: the tokens are issued for the namespaces {'team-a, team-b'}
Future<void> theTokensAreIssuedForTheNamespaces(
  WidgetTester tester,
  String namespaces,
) async {
  expect(
    KubernetesWorld.issuedNamespaces,
    namespaces.split(',').map((n) => n.trim()).toList(),
  );
}
