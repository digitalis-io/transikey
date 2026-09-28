import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/core/models/kubernetes_credentials.dart';

import 'kubernetes_world.dart';

/// Usage: the Kubernetes role {'payments'} allows namespaces labelled {'team=payments'}
///
/// The server returns the selector as JSON, the way it was written.
Future<void> theKubernetesRoleAllowsNamespacesLabelled(
  WidgetTester tester,
  String role,
  String labels,
) async {
  final [key, value] = labels.split('=');
  KubernetesWorld.roles.add(role);
  when(
    () => KubernetesWorld.server.describeKubernetesRole('kubernetes', role),
  ).thenAnswer(
    (_) async => KubernetesRoleInfo(
      namespaceSelector: '{"matchLabels":{"$key":"$value"}}',
      roleType: 'Role',
    ),
  );
}
