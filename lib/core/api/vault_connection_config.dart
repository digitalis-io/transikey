import 'package:equatable/equatable.dart';

/// Secrets engine and auth method mount paths (no leading or trailing slash).
class VaultMounts extends Equatable {
  const VaultMounts({
    this.ssh = 'ssh',
    this.userpass = 'userpass',
    this.approle = 'approle',
    this.ldap = 'ldap',
    this.oidc = 'oidc',
  });

  final String ssh;
  final String userpass;
  final String approle;
  final String ldap;
  final String oidc;

  @override
  List<Object?> get props => [ssh, userpass, approle, ldap, oidc];
}

/// Everything the HTTP client needs to reach a server. Equivalent to
/// `VAULT_ADDR`, `VAULT_NAMESPACE`, `VAULT_SKIP_VERIFY` and `VAULT_CACERT`.
class VaultConnectionConfig extends Equatable {
  const VaultConnectionConfig({
    required this.address,
    this.namespace = '',
    this.tlsVerify = true,
    this.caCertPem,
    this.mounts = const VaultMounts(),
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
    this.maxRetries = 2,
  });

  final String address;
  final String namespace;
  final bool tlsVerify;
  final String? caCertPem;
  final VaultMounts mounts;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int maxRetries;

  /// Base URL without a trailing slash.
  String get baseUrl => address.trim().replaceAll(RegExp(r'/+$'), '');

  @override
  List<Object?> get props => [
    address,
    namespace,
    tlsVerify,
    caCertPem,
    mounts,
    connectTimeout,
    receiveTimeout,
    maxRetries,
  ];
}

/// Holds the active client token in memory only. Shared between the session
/// layer (writer) and the HTTP interceptor (reader) so the token survives a
/// client rebuild when connection settings change.
class TokenHolder {
  String? _token;

  String? get token => _token;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  void set(String token) => _token = token;
  void clear() => _token = null;
}
