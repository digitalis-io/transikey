import '../models/auth_response.dart';
import '../models/database_credentials.dart';
import '../models/health_status.dart';
import '../models/lease_info.dart';
import '../models/ssh_credentials.dart';
import '../models/wrapped_secret.dart';

/// Abstraction over the Vault/OpenBao HTTP API.
///
/// Every method throws a `VaultException` subtype on failure.
abstract class VaultApiClient {
  // --- system -------------------------------------------------------------
  Future<HealthStatus> health();

  // --- authentication -----------------------------------------------------
  /// Validates [token] through `auth/token/lookup-self`.
  Future<AuthResponse> loginWithToken(String token);

  Future<AuthResponse> loginWithUserpass(String username, String password);

  Future<AuthResponse> loginWithAppRole(String roleId, String secretId);

  Future<AuthResponse> renewSelf({Duration? increment});

  Future<void> revokeSelf();

  // --- database -----------------------------------------------------------
  Future<List<String>> listDatabaseRoles();

  Future<DatabaseCredentials> getDatabaseCredentials(String role);

  // --- leases -------------------------------------------------------------
  Future<LeaseInfo> renewLease(String leaseId, {Duration? increment});

  Future<void> revokeLease(String leaseId);

  // --- ssh ----------------------------------------------------------------
  Future<List<String>> listSshRoles();

  Future<SshCredentials> getSshCredentials(
    String role, {
    required String ip,
    String? username,
  });

  Future<SignedCertificate> signPublicKey(
    String role,
    String publicKey, {
    String? validPrincipals,
    Duration? ttl,
  });

  Future<SshAttemptToken> getSshAttemptToken(Map<String, dynamic> params);

  // --- secret sharing -----------------------------------------------------
  Future<WrappedSecret> wrapSecret(Map<String, dynamic> payload, Duration ttl);

  /// Unwraps [wrappingToken]. Works without an authenticated session.
  Future<UnwrappedSecret> unwrapSecret(String wrappingToken);

  Future<void> cubbyholeWrite(String path, Map<String, dynamic> data);

  Future<Map<String, dynamic>> cubbyholeRead(String path);

  Future<void> cubbyholeDelete(String path);

  Future<List<String>> cubbyholeList([String path = '']);
}
