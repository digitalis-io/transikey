import 'dart:convert';

import '../../../core/api/vault_api_client.dart';
import '../../../core/models/auth_response.dart';
import '../../../core/security/secret_store.dart';
import '../domain/auth_repository.dart';
import 'oidc_login_flow.dart';
import '../domain/vault_session.dart';

class VaultAuthRepository implements AuthRepository {
  VaultAuthRepository(this._client, this._store, this._openBrowser);

  static const _tokenKey = 'transikey.session.token';
  static const _metaKey = 'transikey.session.meta';

  final VaultApiClient _client;
  final SecretStore _store;
  final Future<bool> Function(Uri url) _openBrowser;

  @override
  Future<AuthResponse> loginWithToken(String token) =>
      _client.loginWithToken(token);

  @override
  Future<AuthResponse> loginWithUserpass(String username, String password) =>
      _client.loginWithUserpass(username, password);

  @override
  Future<AuthResponse> loginWithAppRole(String roleId, String secretId) =>
      _client.loginWithAppRole(roleId, secretId);

  @override
  Future<AuthResponse> loginWithLdap(String username, String password) =>
      _client.loginWithLdap(username, password);

  @override
  Future<AuthResponse> loginWithOidc(String role) =>
      OidcLoginFlow(client: _client, openBrowser: _openBrowser).run(role);

  @override
  Future<AuthResponse> renewSelf() => _client.renewSelf();

  @override
  Future<void> revokeSelf() => _client.revokeSelf();

  @override
  Future<void> persist(String token, VaultSession session) async {
    await _store.write(_tokenKey, token);
    await _store.write(_metaKey, jsonEncode(session.toJson()));
  }

  @override
  Future<StoredSession?> restore() async {
    final token = await _store.read(_tokenKey);
    final meta = await _store.read(_metaKey);
    if (token == null || token.isEmpty || meta == null) return null;
    try {
      return (
        token: token,
        session: VaultSession.fromJson(
          jsonDecode(meta) as Map<String, dynamic>,
        ),
      );
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> clear() async {
    await _store.delete(_tokenKey);
    await _store.delete(_metaKey);
  }
}
