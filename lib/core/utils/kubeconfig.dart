import 'dart:convert';

import '../models/kubernetes_credentials.dart';
import 'home_paths.dart';
import 'shell_quote.dart';

/// Kubeconfig with one cluster, one user (the service account token) and
/// one context. Vault does not return the API server, so [server] and
/// [caPath] come from the user. An empty [caPath] leaves kubectl on the
/// system trust store.
///
/// Values are written as JSON strings, which YAML reads verbatim.
String kubeconfigYaml(
  KubernetesCredentials creds, {
  required String server,
  String caPath = '',
  Map<String, String>? environment,
}) {
  String q(String v) => jsonEncode(v);
  final name = q('transikey-${creds.mount}-${creds.role}'.replaceAll('/', '-'));
  final ca = expandHome(caPath.trim(), environment);
  return [
    'apiVersion: v1',
    'kind: Config',
    'clusters:',
    '  - name: $name',
    '    cluster:',
    '      server: ${q(server.trim())}',
    if (ca.isNotEmpty) '      certificate-authority: ${q(ca)}',
    'users:',
    '  - name: $name',
    '    user:',
    '      token: ${q(creds.serviceAccountToken)}',
    'contexts:',
    '  - name: $name',
    '    context:',
    '      cluster: $name',
    '      user: $name',
    '      namespace: ${q(creds.serviceAccountNamespace)}',
    'current-context: $name',
    '',
  ].join('\n');
}

/// kubectl against a saved kubeconfig. The token stays in the file, never
/// in argv or the shell history.
String kubectlCommand(String kubeconfigPath, String namespace) =>
    'KUBECONFIG=${shellQuote(kubeconfigPath)} kubectl get pods '
    '-n ${shellQuote(namespace)}';

/// `~/x` -> `<home>/x`. kubectl does not expand `~` in file paths.
String expandHome(String path, [Map<String, String>? environment]) {
  if (path != '~' && !path.startsWith('~/')) return path;
  final home = homeDirectory(environment);
  return home == null ? path : '$home${path.substring(1)}';
}
