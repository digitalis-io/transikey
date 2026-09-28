import '../../../core/api/vault_api_client.dart';
import '../../../core/models/kubernetes_credentials.dart';
import '../domain/kubernetes_repository.dart';

class VaultKubernetesRepository implements KubernetesRepository {
  VaultKubernetesRepository(this._client);

  final VaultApiClient _client;

  @override
  Future<List<String>> discoverMounts() async {
    final mounts = await _client.listSecretMounts();
    return [
      for (final e in mounts.entries)
        if (e.value == 'kubernetes') e.key,
    ]..sort();
  }

  @override
  Future<List<String>> listRoles(String mount) =>
      _client.listKubernetesRoles(mount);

  @override
  Future<KubernetesRoleInfo> describeRole(String mount, String role) =>
      _client.describeKubernetesRole(mount, role);

  @override
  Future<KubernetesCredentials> requestCredentials(
    String mount,
    String role, {
    required String namespace,
    String? ttl,
    bool clusterRoleBinding = false,
  }) => _client.getKubernetesCredentials(
    mount,
    role,
    namespace: namespace,
    ttl: ttl,
    clusterRoleBinding: clusterRoleBinding,
  );
}
