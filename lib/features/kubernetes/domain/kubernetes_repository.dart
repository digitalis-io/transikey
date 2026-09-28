import '../../../core/models/kubernetes_credentials.dart';

abstract class KubernetesRepository {
  /// Kubernetes mounts the server reveals to this token. Empty when it
  /// reveals none.
  Future<List<String>> discoverMounts();
  Future<List<String>> listRoles(String mount);
  Future<KubernetesRoleInfo> describeRole(String mount, String role);
  Future<KubernetesCredentials> requestCredentials(
    String mount,
    String role, {
    required String namespace,
    String? ttl,
    bool clusterRoleBinding = false,
  });
}
