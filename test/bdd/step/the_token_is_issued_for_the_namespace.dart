import 'package:flutter_test/flutter_test.dart';

import 'kubernetes_world.dart';

/// Usage: the token is issued for the namespace {'team-b'}
Future<void> theTokenIsIssuedForTheNamespace(
  WidgetTester tester,
  String namespace,
) async {
  expect(KubernetesWorld.lastNamespace, namespace);
  expect(find.text('kubernetes/developer'), findsOneWidget);
}
