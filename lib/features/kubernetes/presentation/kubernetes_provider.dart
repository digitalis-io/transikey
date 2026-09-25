import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/errors/vault_exception.dart';
import '../../../core/models/kubernetes_credentials.dart';
import '../../../core/widgets/role_picker.dart';
import '../../auth/presentation/session_provider.dart';
import '../../leases/presentation/leases_provider.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_provider.dart';
import '../data/vault_kubernetes_repository.dart';
import '../domain/kubernetes_repository.dart';

/// A role on one Kubernetes mount.
typedef KubernetesRoleRef = ({String mount, String role});

/// What to ask for: the role plus the request options.
typedef KubernetesRequest = ({
  KubernetesRoleRef role,
  String namespace,
  String? ttl,
  bool clusterRoleBinding,
});

final kubernetesRepositoryProvider = Provider<KubernetesRepository>(
  (ref) => VaultKubernetesRepository(ref.watch(apiClientProvider)),
);

/// Kubernetes mounts: what the server reveals, else the mounts from
/// settings.
final kubernetesMountsProvider = FutureProvider<List<String>>((ref) async {
  if (!ref.watch(sessionActiveProvider)) return const [];
  final configured = ref.watch(
    settingsProvider.select(
      (s) => (s.value ?? const AppSettings()).kubernetesMountList,
    ),
  );
  try {
    final found = await ref
        .watch(kubernetesRepositoryProvider)
        .discoverMounts();
    return found.isEmpty ? configured : found;
  } on VaultException {
    return configured;
  }
});

/// Roles of every mount. A mount that cannot be listed carries its error
/// instead of failing the others.
final kubernetesRolesProvider = FutureProvider<List<RoleGroup>>((ref) async {
  final mounts = await ref.watch(kubernetesMountsProvider.future);
  final repository = ref.watch(kubernetesRepositoryProvider);
  Future<RoleGroup> list(String mount) async {
    try {
      return RoleGroup(name: mount, roles: await repository.listRoles(mount));
    } on VaultException catch (e) {
      return RoleGroup(name: mount, error: e.message);
    }
  }

  return Future.wait(mounts.map(list));
});

/// Allowed namespaces of a role, or null when the token may not read the
/// role. Null means: the user types the namespace.
final kubernetesRoleInfoProvider = FutureProvider.autoDispose
    .family<KubernetesRoleInfo?, KubernetesRoleRef>((ref, role) async {
      if (!ref.watch(sessionActiveProvider)) return null;
      try {
        return await ref
            .watch(kubernetesRepositoryProvider)
            .describeRole(role.mount, role.role);
      } on VaultException {
        return null;
      }
    });

/// Most recently issued token. `AsyncData(null)` is the empty state.
final kubernetesCredentialsProvider =
    AsyncNotifierProvider<
      KubernetesCredentialsNotifier,
      KubernetesCredentials?
    >(KubernetesCredentialsNotifier.new);

class KubernetesCredentialsNotifier
    extends AsyncNotifier<KubernetesCredentials?> {
  // A cleared or repeated request must not resurface a stale answer.
  int _generation = 0;

  @override
  Future<KubernetesCredentials?> build() async => null;

  Future<void> request(KubernetesRequest request) async {
    final generation = ++_generation;
    state = const AsyncLoading();
    final result = await AsyncValue.guard<KubernetesCredentials?>(() async {
      final creds = await ref
          .read(kubernetesRepositoryProvider)
          .requestCredentials(
            request.role.mount,
            request.role.role,
            namespace: request.namespace,
            ttl: request.ttl,
            clusterRoleBinding: request.clusterRoleBinding,
          );
      ref.read(leasesProvider.notifier).track(creds.lease, creds.key);
      // Only a namespace the server accepted is worth offering again. A
      // failed save costs the suggestion, not the token already issued.
      try {
        await ref
            .read(settingsProvider.notifier)
            .change((s) => s.withRecentNamespace(creds.key, request.namespace));
      } catch (_) {}
      return creds;
    });
    if (ref.mounted && generation == _generation) state = result;
  }

  void clear() {
    _generation++;
    state = const AsyncData(null);
  }
}
