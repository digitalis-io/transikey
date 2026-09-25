import 'package:mocktail/mocktail.dart';
import 'package:transikey/core/api/vault_api_client.dart';
import 'package:transikey/core/security/clipboard_guard.dart';

class FakeKubernetesServer extends Mock implements VaultApiClient {}

/// Keeps copies in the test instead of the system clipboard.
class RecordingClipboard extends ClipboardGuard {
  final copies = <String>[];

  @override
  Future<void> copy(String value) async => copies.add(value);
}

/// State shared by the Kubernetes steps of one scenario.
class KubernetesWorld {
  static late FakeKubernetesServer server;
  static late RecordingClipboard clipboard;

  /// Mount path -> engine type, as the server reveals them.
  static late Map<String, String> mounts;

  /// `cluster_role_binding` of the last token request.
  static bool? lastClusterRoleBinding;
}
