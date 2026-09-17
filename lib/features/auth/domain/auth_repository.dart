import '../../../core/models/auth_response.dart';
import 'vault_session.dart';

/// A persisted login: the secret token plus its public description.
typedef StoredSession = ({String token, VaultSession session});

abstract class AuthRepository {
  Future<AuthResponse> loginWithToken(String token);
  Future<AuthResponse> loginWithUserpass(String username, String password);
  Future<AuthResponse> loginWithAppRole(String roleId, String secretId);
  Future<AuthResponse> renewSelf();
  Future<void> revokeSelf();

  Future<void> persist(String token, VaultSession session);
  Future<StoredSession?> restore();
  Future<void> clear();
}
