import '../models/auth_response.dart';
import '../models/database_credentials.dart';
import '../utils/db_target_detection.dart';
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

  Future<AuthResponse> loginWithLdap(String username, String password);

  /// First leg of the OIDC flow: the identity provider URL to open in a
  /// browser. [role] may be empty to use the mount's default role.
  Future<Uri> oidcAuthUrl({
    required String role,
    required Uri redirectUri,
    required String clientNonce,
  });

  /// Last leg of the OIDC flow: trades the provider's `code` for a token.
  Future<AuthResponse> oidcCallback({
    required String state,
    required String code,
    required String clientNonce,
  });

  Future<AuthResponse> renewSelf({Duration? increment});

  Future<void> revokeSelf();

  // --- database -----------------------------------------------------------
  /// Secrets engine mounts visible to the token, as `path -> type`, paths
  /// without a trailing slash. Backed by `sys/internal/ui/mounts`, which
  /// needs no policy of its own.
  Future<Map<String, String>> listSecretMounts();

  Future<List<String>> listDatabaseRoles(String mount);

  /// Engine and address behind [role], read from the role and connection
  /// configuration. Most least-privilege tokens may not read either: that
  /// surfaces as a [PermissionDeniedException].
  Future<DetectedDatabase> describeDatabaseRole(String mount, String role);

  Future<DatabaseCredentials> getDatabaseCredentials(String mount, String role);

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
