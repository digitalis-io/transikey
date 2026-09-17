import 'package:dio/dio.dart';

import '../errors/vault_exception.dart';
import '../models/auth_response.dart';
import '../models/database_credentials.dart';
import '../models/health_status.dart';
import '../models/lease_info.dart';
import '../models/ssh_credentials.dart';
import '../models/vault_envelope.dart';
import '../models/wrapped_secret.dart';
import '../utils/duration_format.dart';
import 'error_mapper.dart';
import 'interceptors/auth_interceptor.dart';
import 'vault_api_client.dart';
import 'vault_connection_config.dart';

/// [VaultApiClient] backed by Dio. Compatible with HashiCorp Vault (OSS and
/// Enterprise) and OpenBao, which share the same `/v1` HTTP API.
class DioVaultApiClient implements VaultApiClient {
  DioVaultApiClient({required Dio dio, required VaultConnectionConfig config})
    : _dio = dio,
      _mounts = config.mounts;

  final Dio _dio;
  final VaultMounts _mounts;

  static final _noAuth = Options(extra: {extraNoAuth: true});

  // --- system -------------------------------------------------------------

  @override
  Future<HealthStatus> health() => _guard(() async {
    final response = await _dio.get<dynamic>(
      '/v1/sys/health',
      // Always answer 200 so sealed and standby nodes still report state.
      queryParameters: const {
        'standbyok': 'true',
        'perfstandbyok': 'true',
        'sealedcode': '200',
        'uninitcode': '200',
        'drsecondarycode': '200',
      },
      options: Options(extra: {extraNoAuth: true, extraNoRetry: true}),
    );
    return HealthStatus.fromData(_asMap(response.data));
  });

  // --- authentication -----------------------------------------------------

  @override
  Future<AuthResponse> loginWithToken(String token) => _guard(() async {
    if (token.trim().isEmpty) {
      throw const ValidationException('Token is required.');
    }
    final envelope = await _request(
      'GET',
      '/v1/auth/token/lookup-self',
      options: Options(headers: {vaultTokenHeader: token.trim()}),
    );
    return AuthResponse.fromLookup(token.trim(), envelope.data ?? const {});
  });

  @override
  Future<AuthResponse> loginWithUserpass(
    String username,
    String password,
  ) => _guard(() async {
    if (username.trim().isEmpty || password.isEmpty) {
      throw const ValidationException('Username and password are required.');
    }
    final envelope = await _request(
      'POST',
      '/v1/auth/${_mounts.userpass}/login/${Uri.encodeComponent(username.trim())}',
      data: {'password': password},
      options: _noAuth,
    );
    return _authFrom(envelope);
  });

  @override
  Future<AuthResponse> loginWithAppRole(String roleId, String secretId) =>
      _guard(() async {
        if (roleId.trim().isEmpty) {
          throw const ValidationException('Role ID is required.');
        }
        final envelope = await _request(
          'POST',
          '/v1/auth/${_mounts.approle}/login',
          data: {'role_id': roleId.trim(), 'secret_id': secretId.trim()},
          options: _noAuth,
        );
        return _authFrom(envelope);
      });

  @override
  Future<AuthResponse> renewSelf({Duration? increment}) => _guard(() async {
    final envelope = await _request(
      'POST',
      '/v1/auth/token/renew-self',
      data: {if (increment != null) 'increment': vaultTtl(increment)},
    );
    return _authFrom(envelope);
  });

  @override
  Future<void> revokeSelf() =>
      _guard(() => _request('POST', '/v1/auth/token/revoke-self'));

  // --- database -----------------------------------------------------------

  @override
  Future<List<String>> listDatabaseRoles() =>
      _guard(() => _list('/v1/${_mounts.database}/roles'));

  @override
  Future<DatabaseCredentials> getDatabaseCredentials(String role) =>
      _guard(() async {
        final envelope = await _request(
          'GET',
          '/v1/${_mounts.database}/creds/${_segment(role, 'Role')}',
        );
        final data = envelope.data ?? const {};
        return DatabaseCredentials(
          role: role,
          username: data['username'] as String? ?? '',
          password: data['password'] as String? ?? '',
          lease: _leaseFrom(envelope),
        );
      });

  // --- leases -------------------------------------------------------------

  @override
  Future<LeaseInfo> renewLease(String leaseId, {Duration? increment}) =>
      _guard(() async {
        final envelope = await _request(
          'PUT',
          '/v1/sys/leases/renew',
          data: {
            'lease_id': leaseId,
            if (increment != null) 'increment': increment.inSeconds,
          },
        );
        return _leaseFrom(envelope);
      });

  @override
  Future<void> revokeLease(String leaseId) => _guard(
    () => _request('PUT', '/v1/sys/leases/revoke', data: {'lease_id': leaseId}),
  );

  // --- ssh ----------------------------------------------------------------

  @override
  Future<List<String>> listSshRoles() =>
      _guard(() => _list('/v1/${_mounts.ssh}/roles'));

  @override
  Future<SshCredentials> getSshCredentials(
    String role, {
    required String ip,
    String? username,
  }) => _guard(() async {
    if (ip.trim().isEmpty) {
      throw const ValidationException('Target IP address is required.');
    }
    final envelope = await _request(
      'POST',
      '/v1/${_mounts.ssh}/creds/${_segment(role, 'Role')}',
      data: {
        'ip': ip.trim(),
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim(),
      },
    );
    final data = envelope.data ?? const {};
    return SshCredentials(
      role: role,
      username: data['username'] as String? ?? '',
      otp: data['key'] as String? ?? '',
      ip: data['ip'] as String? ?? ip.trim(),
      port: (data['port'] as num?)?.toInt() ?? 22,
      lease: _leaseFrom(envelope),
    );
  });

  @override
  Future<SignedCertificate> signPublicKey(
    String role,
    String publicKey, {
    String? validPrincipals,
    Duration? ttl,
  }) => _guard(() async {
    if (publicKey.trim().isEmpty) {
      throw const ValidationException('Public key is required.');
    }
    final envelope = await _request(
      'POST',
      '/v1/${_mounts.ssh}/sign/${_segment(role, 'Role')}',
      data: {
        'public_key': publicKey.trim(),
        if (validPrincipals != null && validPrincipals.trim().isNotEmpty)
          'valid_principals': validPrincipals.trim(),
        if (ttl != null) 'ttl': vaultTtl(ttl),
      },
    );
    final data = envelope.data ?? const {};
    return SignedCertificate(
      role: role,
      serialNumber: data['serial_number'] as String? ?? '',
      signedKey: (data['signed_key'] as String? ?? '').trim(),
    );
  });

  @override
  Future<SshAttemptToken> getSshAttemptToken(Map<String, dynamic> params) =>
      _guard(() async {
        final envelope = await _request(
          'POST',
          '/v1/${_mounts.ssh}/get-attempt-token',
          data: params,
        );
        final data = Map<String, dynamic>.of(envelope.data ?? const {});
        final token =
            (data.remove('token') ?? data.remove('attempt_token')) as String? ??
            '';
        return SshAttemptToken(
          token: token,
          metadata: data.map((k, v) => MapEntry(k, '$v')),
          leaseDuration: envelope.leaseTtl,
        );
      });

  // --- secret sharing -----------------------------------------------------

  @override
  Future<WrappedSecret> wrapSecret(
    Map<String, dynamic> payload,
    Duration ttl,
  ) => _guard(() async {
    if (payload.isEmpty) {
      throw const ValidationException('Nothing to wrap.');
    }
    if (ttl <= Duration.zero) {
      throw const ValidationException('TTL must be positive.');
    }
    final envelope = await _request(
      'POST',
      '/v1/sys/wrapping/wrap',
      data: payload,
      options: Options(headers: {vaultWrapTtlHeader: vaultTtl(ttl)}),
    );
    final info = envelope.wrapInfo;
    if (info == null) {
      throw const VaultException('Server returned no wrapping token.');
    }
    return WrappedSecret(
      token: info['token'] as String? ?? '',
      accessor: info['accessor'] as String? ?? '',
      ttl: Duration(seconds: (info['ttl'] as num?)?.toInt() ?? 0),
      creationTime:
          DateTime.tryParse(info['creation_time'] as String? ?? '') ??
          DateTime.now().toUtc(),
      creationPath: info['creation_path'] as String? ?? '',
    );
  });

  @override
  Future<UnwrappedSecret> unwrapSecret(String wrappingToken) =>
      _guard(() async {
        if (wrappingToken.trim().isEmpty) {
          throw const ValidationException('Wrapping token is required.');
        }
        final envelope = await _request(
          'POST',
          '/v1/sys/wrapping/unwrap',
          options: Options(headers: {vaultTokenHeader: wrappingToken.trim()}),
        );
        return UnwrappedSecret(
          data: envelope.data ?? envelope.auth ?? const {},
          requestId: envelope.requestId ?? '',
          leaseId: envelope.leaseId,
          leaseDuration: envelope.leaseTtl,
          renewable: envelope.renewable,
          warnings: envelope.warnings ?? const [],
        );
      });

  @override
  Future<void> cubbyholeWrite(String path, Map<String, dynamic> data) => _guard(
    () => _request('POST', '/v1/cubbyhole/${_path(path)}', data: data),
  );

  @override
  Future<Map<String, dynamic>> cubbyholeRead(String path) => _guard(
    () async =>
        (await _request('GET', '/v1/cubbyhole/${_path(path)}')).data ??
        const {},
  );

  @override
  Future<void> cubbyholeDelete(String path) =>
      _guard(() => _request('DELETE', '/v1/cubbyhole/${_path(path)}'));

  @override
  Future<List<String>> cubbyholeList([String path = '']) => _guard(() async {
    try {
      final clean = path.trim().replaceAll(RegExp(r'^/+|/+$'), '');
      return await _list('/v1/cubbyhole/$clean');
    } on DioException catch (e) {
      // LIST on an empty cubbyhole answers 404.
      if (e.response?.statusCode == 404) return const <String>[];
      rethrow;
    }
  });

  // --- helpers ------------------------------------------------------------

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<VaultEnvelope> _request(
    String method,
    String path, {
    Object? data,
    Options? options,
  }) async {
    final response = await _dio.request<dynamic>(
      path,
      data: data,
      options: (options ?? Options()).copyWith(method: method),
    );
    final body = response.data;
    if (body is Map) return VaultEnvelope.fromJson(_asMap(body));
    return const VaultEnvelope(); // 204 No Content
  }

  /// `GET ?list=true` is the portable form of the LIST verb.
  Future<List<String>> _list(String path) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: const {'list': 'true'},
    );
    final data = _asMap(response.data)['data'];
    return data is Map && data['keys'] is List
        ? (data['keys'] as List).map((e) => '$e').toList()
        : const [];
  }

  AuthResponse _authFrom(VaultEnvelope envelope) {
    final auth = envelope.auth;
    if (auth == null) {
      throw const AuthenticationException('Server returned no token.');
    }
    return AuthResponse.fromAuthBlock(auth);
  }

  LeaseInfo _leaseFrom(VaultEnvelope envelope) => LeaseInfo(
    leaseId: envelope.leaseId,
    leaseDuration: envelope.leaseTtl,
    renewable: envelope.renewable,
  );

  String _segment(String value, String label) {
    final clean = value.trim();
    if (clean.isEmpty) throw ValidationException('$label is required.');
    return clean.split('/').map(Uri.encodeComponent).join('/');
  }

  String _path(String value) {
    final clean = value.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (clean.isEmpty) throw const ValidationException('Path is required.');
    return clean.split('/').map(Uri.encodeComponent).join('/');
  }

  Map<String, dynamic> _asMap(Object? body) =>
      body is Map ? Map<String, dynamic>.from(body) : const {};
}
