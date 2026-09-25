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

/// What to ask for: the role, its namespaces (one token each) and the
/// request options.
typedef KubernetesRequest = ({
  KubernetesRoleRef role,
  List<String> namespaces,
  String? ttl,
  bool clusterRoleBinding,
});

/// Most namespaces in one request. Each one creates a service account and
/// a binding on the cluster: one click must not create dozens.
const maxNamespacesPerRequest = 10;

/// Namespaces to request: the chosen ones plus what is typed in the field,
/// trimmed, without duplicates, in order.
List<String> namespacesToRequest(List<String> chosen, String typed) {
  final all = <String>{
    for (final n in [...chosen, typed])
      if (n.trim().isNotEmpty) n.trim(),
  };
  return all.toList();
}

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

/// Most recently issued tokens. `AsyncData(null)` is the empty state.
final kubernetesCredentialsProvider =
    AsyncNotifierProvider<KubernetesCredentialsNotifier, KubernetesTokenSet?>(
      KubernetesCredentialsNotifier.new,
    );

class KubernetesCredentialsNotifier extends AsyncNotifier<KubernetesTokenSet?> {
  // A cleared or repeated request must not resurface a stale answer.
  int _generation = 0;

  @override
  Future<KubernetesTokenSet?> build() async => null;

  /// One request per namespace. Refused namespaces are listed next to the
  /// issued tokens; when every namespace is refused, the first error is
  /// the result and the card stays empty.
  Future<void> request(KubernetesRequest request) async {
    final generation = ++_generation;
    state = const AsyncLoading();
    final result = await AsyncValue.guard<KubernetesTokenSet?>(() async {
      final namespaces = request.namespaces;
      if (namespaces.isEmpty) {
        throw const ValidationException('Namespace is required.');
      }
      if (namespaces.length > maxNamespacesPerRequest) {
        throw const ValidationException(
          'At most $maxNamespacesPerRequest namespaces at once.',
        );
      }
      final repository = ref.read(kubernetesRepositoryProvider);
      final outcomes = await Future.wait([
        for (final namespace in namespaces)
          repository
              .requestCredentials(
                request.role.mount,
                request.role.role,
                namespace: namespace,
                ttl: request.ttl,
                clusterRoleBinding: request.clusterRoleBinding,
              )
              .then<Object>((c) => c, onError: (Object e) => e),
      ]);
      final tokens = outcomes.whereType<KubernetesCredentials>().toList();
      final errors = {
        for (var i = 0; i < namespaces.length; i++)
          if (outcomes[i] is! KubernetesCredentials) namespaces[i]: outcomes[i],
      };
      if (tokens.isEmpty) throw errors.values.first;
      for (final t in tokens) {
        ref
            .read(leasesProvider.notifier)
            .track(t.lease, '${t.key} · ${t.serviceAccountNamespace}');
      }
      // Only namespaces the server accepted are worth offering again. A
      // failed save costs the suggestion, not the tokens already issued.
      try {
        await ref
            .read(settingsProvider.notifier)
            .change(
              (s) => tokens.reversed.fold(
                s,
                (s, t) =>
                    s.withRecentNamespace(t.key, t.serviceAccountNamespace),
              ),
            );
      } catch (_) {}
      return KubernetesTokenSet(
        mount: request.role.mount,
        role: request.role.role,
        tokens: tokens,
        failures: {
          for (final e in errors.entries)
            e.key: e.value is VaultException
                ? (e.value as VaultException).message
                : '${e.value}',
        },
      );
    });
    if (ref.mounted && generation == _generation) state = result;
  }

  /// Revokes every token of the result, then clears it.
  Future<void> revokeAll() async {
    final tokens = state.value?.tokens ?? const [];
    final leases = ref.read(leasesProvider.notifier);
    await Future.wait([for (final t in tokens) leases.revoke(t.lease.leaseId)]);
    clear();
  }

  void clear() {
    _generation++;
    state = const AsyncData(null);
  }
}
