import '../../../core/api/vault_api_client.dart';
import '../../../core/models/ssh_credentials.dart';
import '../domain/ssh_repository.dart';

class VaultSshRepository implements SshRepository {
  VaultSshRepository(this._client);

  final VaultApiClient _client;

  @override
  Future<List<String>> listRoles() => _client.listSshRoles();

  @override
  Future<SshCredentials> requestOtp(
    String role, {
    required String ip,
    String? username,
  }) => _client.getSshCredentials(role, ip: ip, username: username);

  @override
  Future<SignedCertificate> signPublicKey(
    String role,
    String publicKey, {
    String? validPrincipals,
    Duration? ttl,
  }) => _client.signPublicKey(
    role,
    publicKey,
    validPrincipals: validPrincipals,
    ttl: ttl,
  );

  @override
  Future<SshAttemptToken> requestAttemptToken(Map<String, dynamic> params) =>
      _client.getSshAttemptToken(params);
}
