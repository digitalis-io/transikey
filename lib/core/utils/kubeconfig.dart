import 'dart:convert';
import 'dart:io';

import '../models/kubernetes_credentials.dart';
import 'home_paths.dart';
import 'shell_quote.dart';

/// Kubeconfig with one cluster, one user (the service account token) and
/// one context. Vault does not return the API server, so [server] and
/// [caPem] come from the user. The CA is embedded, not referenced by path,
/// so the file works from any directory and on any machine. An empty
/// [caPem] leaves kubectl on the system trust store.
///
/// Values are written as JSON strings, which YAML reads verbatim.
String kubeconfigYaml(
  KubernetesCredentials creds, {
  required String server,
  String caPem = '',
}) {
  String q(String v) => jsonEncode(v);
  final name = q('transikey-${creds.mount}-${creds.role}'.replaceAll('/', '-'));
  final ca = caPem.trim().isEmpty
      ? ''
      : base64.encode(utf8.encode('${caPem.trim()}\n'));
  return [
    'apiVersion: v1',
    'kind: Config',
    'clusters:',
    '  - name: $name',
    '    cluster:',
    '      server: ${q(server.trim())}',
    if (ca.isNotEmpty) '      certificate-authority-data: ${q(ca)}',
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

/// PEM text of the CA certificate at [path], or empty when [path] is empty.
/// Throws a [FormatException] with a message for the user when the path is
/// relative (the app's working directory means nothing to the user), the
/// file cannot be read, or it holds no certificate.
Future<String> readCaCertificate(
  String path, [
  Map<String, String>? environment,
]) async {
  final clean = expandHome(path.trim(), environment);
  if (clean.isEmpty) return '';
  if (!File(clean).isAbsolute) {
    throw FormatException('Use an absolute CA certificate path: $clean');
  }
  final String pem;
  try {
    pem = await File(clean).readAsString();
  } on FileSystemException {
    throw FormatException('Cannot read the CA certificate: $clean');
  }
  if (!pem.contains('-----BEGIN CERTIFICATE-----')) {
    throw FormatException('No PEM certificate in $clean');
  }
  return pem;
}

/// kubectl against a saved kubeconfig. The token stays in the file, never
/// in argv or the shell history.
String kubectlCommand(String kubeconfigPath, String namespace) =>
    'KUBECONFIG=${shellQuote(kubeconfigPath)} kubectl get pods '
    '-n ${shellQuote(namespace)}';

/// `~/x` -> `<home>/x`. Dart file APIs do not expand `~`.
String expandHome(String path, [Map<String, String>? environment]) {
  if (path != '~' && !path.startsWith('~/')) return path;
  final home = homeDirectory(environment);
  return home == null ? path : '$home${path.substring(1)}';
}
