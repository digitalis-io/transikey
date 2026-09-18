import 'dart:io';

/// What the `bao` / `vault` CLI would use on this machine: the environment
/// variables and the token helper file. `BAO_*` wins over `VAULT_*`, as it
/// does in the OpenBao CLI.
///
/// Note: an app started from Finder, the Start menu or a desktop launcher
/// does not see variables exported in a shell profile. The token file is
/// found either way.
class CliEnvironment {
  const CliEnvironment({
    this.address,
    this.addressSource,
    this.namespace,
    this.skipVerify = false,
    this.caCertPath,
    this.tokenSource,
    String? Function()? readToken,
  }) : _readToken = readToken;

  final String? address;

  /// Name of the variable the address came from, for display.
  final String? addressSource;
  final String? namespace;
  final bool skipVerify;
  final String? caCertPath;

  /// Where a token is available (`BAO_TOKEN`, `~/.vault-token`, …) or null.
  final String? tokenSource;

  final String? Function()? _readToken;

  bool get hasAnything => address != null || tokenSource != null;

  /// Reads the token only when asked: never at detection time.
  String? readToken() => _readToken?.call();

  /// PEM content of the CA file, or null when unset or unreadable.
  String? readCaCert() {
    final path = caCertPath;
    if (path == null) return null;
    try {
      final pem = File(path).readAsStringSync();
      return pem.contains('BEGIN CERTIFICATE') ? pem : null;
    } on FileSystemException {
      return null;
    }
  }

  static CliEnvironment detect() => from(Platform.environment);

  /// [fileExists] and [readFile] are injectable for tests.
  static CliEnvironment from(
    Map<String, String> env, {
    bool Function(String path)? fileExists,
    String Function(String path)? readFile,
  }) {
    fileExists ??= (p) => File(p).existsSync();
    readFile ??= (p) => File(p).readAsStringSync();

    (String, String)? first(List<String> names) {
      for (final name in names) {
        final value = env[name]?.trim() ?? '';
        if (value.isNotEmpty) return (name, value);
      }
      return null;
    }

    final address = first(['BAO_ADDR', 'VAULT_ADDR']);
    final uri = address == null ? null : Uri.tryParse(address.$2);
    final validAddress =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    final skip = first(['BAO_SKIP_VERIFY', 'VAULT_SKIP_VERIFY'])?.$2;
    final envToken = first(['BAO_TOKEN', 'VAULT_TOKEN']);

    String? tokenSource;
    String? Function()? readToken;
    if (envToken != null) {
      tokenSource = envToken.$1;
      readToken = () => envToken.$2;
    } else {
      final home = first(['HOME', 'USERPROFILE'])?.$2;
      if (home != null) {
        final path = '$home${Platform.pathSeparator}.vault-token';
        if (fileExists(path)) {
          tokenSource = '~/.vault-token';
          readToken = () {
            try {
              final token = readFile!(path).trim();
              return token.isEmpty ? null : token;
            } on FileSystemException {
              return null;
            }
          };
        }
      }
    }

    return CliEnvironment(
      address: validAddress ? address?.$2 : null,
      addressSource: validAddress ? address?.$1 : null,
      namespace: first(['BAO_NAMESPACE', 'VAULT_NAMESPACE'])?.$2,
      skipVerify: const {'1', 'true', 't', 'yes'}.contains(skip?.toLowerCase()),
      caCertPath: first(['BAO_CACERT', 'VAULT_CACERT'])?.$2,
      tokenSource: tokenSource,
      readToken: readToken,
    );
  }

  @override
  String toString() =>
      'CliEnvironment(address: $address, tokenSource: $tokenSource)';
}
