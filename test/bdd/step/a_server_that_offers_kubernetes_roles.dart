import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/core/errors/vault_exception.dart';
import 'package:transikey/core/models/kubernetes_credentials.dart';
import 'package:transikey/core/models/lease_info.dart';

import 'kubernetes_world.dart';

/// Usage: a server that offers Kubernetes roles
Future<void> aServerThatOffersKubernetesRoles(WidgetTester tester) async {
  final server = KubernetesWorld.server = FakeKubernetesServer();
  KubernetesWorld.clipboard = RecordingClipboard();
  KubernetesWorld.lastClusterRoleBinding = null;
  KubernetesWorld.lastNamespace = null;
  KubernetesWorld.mounts = {'kubernetes': 'kubernetes', 'ssh': 'ssh'};
  when(server.listSecretMounts).thenAnswer((_) async => KubernetesWorld.mounts);
  KubernetesWorld.roles = ['developer', 'viewer'];
  when(
    () => server.listKubernetesRoles('kubernetes'),
  ).thenAnswer((_) async => KubernetesWorld.roles);
  when(
    () => server.describeKubernetesRole(any(), any()),
  ).thenThrow(const PermissionDeniedException('Permission denied.'));
  when(
    () => server.describeKubernetesRole('kubernetes', 'developer'),
  ).thenAnswer(
    (_) async => const KubernetesRoleInfo(
      allowedNamespaces: ['team-a', 'team-b'],
      roleType: 'Role',
    ),
  );
  when(
    () => server.getKubernetesCredentials(
      any(),
      any(),
      namespace: any(named: 'namespace'),
      ttl: any(named: 'ttl'),
      clusterRoleBinding: any(named: 'clusterRoleBinding'),
    ),
  ).thenAnswer((call) async {
    final [mount as String, role as String] = call.positionalArguments;
    final namespace = call.namedArguments[#namespace] as String;
    // The server enforces allowed_kubernetes_namespaces, not the app.
    if (role == 'developer' && !['team-a', 'team-b'].contains(namespace)) {
      throw ValidationException('Namespace $namespace is not allowed.');
    }
    KubernetesWorld.lastNamespace = namespace;
    KubernetesWorld.lastClusterRoleBinding =
        call.namedArguments[#clusterRoleBinding] as bool;
    return KubernetesCredentials(
      mount: mount,
      role: role,
      serviceAccountToken: 'k8s-token-$role',
      serviceAccountName: 'v-demo-$role',
      serviceAccountNamespace: namespace,
      lease: LeaseInfo(
        leaseId: '$mount/creds/$role/1',
        leaseDuration: const Duration(minutes: 10),
        renewable: false,
      ),
    );
  });
}
