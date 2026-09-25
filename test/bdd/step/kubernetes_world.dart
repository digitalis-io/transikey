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

  /// Roles of the `kubernetes` mount.
  static late List<String> roles;

  /// Mount path -> engine type, as the server reveals them.
  static late Map<String, String> mounts;

  /// CA files the fake disk holds: path -> PEM.
  static const caFiles = {
    '/etc/k8s/ca.crt':
        '-----BEGIN CERTIFICATE-----\nMIIBtest\n-----END CERTIFICATE-----',
  };

  /// Reads [caFiles]; any other path fails like an unreadable file.
  static Future<String> readCa(String path) async {
    if (path.isEmpty) return '';
    final pem = caFiles[path];
    if (pem == null) {
      throw FormatException('Cannot read the CA certificate: $path');
    }
    return pem;
  }

  /// `cluster_role_binding` of the last token request.
  static bool? lastClusterRoleBinding;

  /// Namespaces the server issued tokens for, in request order.
  static late List<String> issuedNamespaces;
}
