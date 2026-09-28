import 'dart:convert';
import 'dart:io';

import '../models/kubernetes_credentials.dart';
import 'home_paths.dart';
import 'shell_quote.dart';

/// Kubeconfig with one cluster and, per token, one user and one context
/// set to the token's namespace. The first token's context is current.
/// Vault does not return the API server, so [server] and [caPem] come from
/// the user. The CA is embedded, not referenced by path, so the file works
/// from any directory and on any machine. An empty [caPem] leaves kubectl
/// on the system trust store.
///
/// Values are written as JSON strings, which YAML reads verbatim.
String kubeconfigYaml(
  List<KubernetesCredentials> tokens, {
  required String server,
  String caPem = '',
}) {
  if (tokens.isEmpty) throw ArgumentError.value(tokens, 'tokens', 'empty');
  String q(String v) => jsonEncode(v);
  final cluster = q(kubeClusterName(tokens.first.mount));
  final ca = caPem.trim().isEmpty
      ? ''
      : base64.encode(utf8.encode('${caPem.trim()}\n'));
  return [
    'apiVersion: v1',
    'kind: Config',
    'clusters:',
    '  - name: $cluster',
    '    cluster:',
    '      server: ${q(server.trim())}',
    if (ca.isNotEmpty) '      certificate-authority-data: ${q(ca)}',
    'users:',
    for (final t in tokens) ...[
      '  - name: ${q(kubeContextName(t))}',
      '    user:',
      '      token: ${q(t.serviceAccountToken)}',
    ],
    'contexts:',
    for (final t in tokens) ...[
      '  - name: ${q(kubeContextName(t))}',
      '    context:',
      '      cluster: $cluster',
      '      user: ${q(kubeContextName(t))}',
      '      namespace: ${q(t.serviceAccountNamespace)}',
    ],
    'current-context: ${q(kubeContextName(tokens.first))}',
    '',
  ].join('\n');
}

/// `transikey-<mount>`, slashes turned into dashes.
String kubeClusterName(String mount) => 'transikey-$mount'.replaceAll('/', '-');

/// `transikey-<mount>-<role>-<namespace>`: one context per token.
String kubeContextName(KubernetesCredentials t) =>
    '${kubeClusterName(t.mount)}-${t.role}-${t.serviceAccountNamespace}'
        .replaceAll('/', '-');

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

/// kubectl against a saved kubeconfig, in the context of [token]. `-n`
/// alone would not do: each namespace has its own token. The token stays
/// in the file, never in argv or the shell history.
String kubectlCommand(String kubeconfigPath, KubernetesCredentials token) =>
    'KUBECONFIG=${shellQuote(kubeconfigPath)} kubectl '
    '--context ${shellQuote(kubeContextName(token))} get pods '
    '-n ${shellQuote(token.serviceAccountNamespace)}';

/// `~/x` -> `<home>/x`. Dart file APIs do not expand `~`.
String expandHome(String path, [Map<String, String>? environment]) {
  if (path != '~' && !path.startsWith('~/')) return path;
  final home = homeDirectory(environment);
  return home == null ? path : '$home${path.substring(1)}';
}
