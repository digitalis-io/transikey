import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/vault_exception.dart';
import '../../../core/models/auth_response.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/vault_session.dart';
import 'session_provider.dart';

final vaultAuthProvider = AsyncNotifierProvider<VaultAuthNotifier, void>(
  VaultAuthNotifier.new,
);

/// Runs login attempts. `AsyncLoading` while a login is in flight,
/// `AsyncError` when it failed; success moves [vaultSessionProvider] to
/// authenticated.
class VaultAuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> loginWithToken(String token) => _login(
    AuthMethod.token,
    () => ref.read(authRepositoryProvider).loginWithToken(token),
  );

  Future<void> loginWithUserpass(String username, String password) => _login(
    AuthMethod.userpass,
    () =>
        ref.read(authRepositoryProvider).loginWithUserpass(username, password),
  );

  Future<void> loginWithAppRole(String roleId, String secretId) => _login(
    AuthMethod.approle,
    () => ref.read(authRepositoryProvider).loginWithAppRole(roleId, secretId),
  );

  Future<void> loginWithLdap(String username, String password) => _login(
    AuthMethod.ldap,
    () => ref.read(authRepositoryProvider).loginWithLdap(username, password),
  );

  /// Opens the system browser and waits for the provider to call back.
  Future<void> loginWithOidc(String role) => _login(
    AuthMethod.oidc,
    () => ref.read(authRepositoryProvider).loginWithOidc(role),
  );

  Future<void> _login(
    AuthMethod method,
    Future<AuthResponse> Function() attempt,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final settings = await ref.read(settingsProvider.future);
      if (!settings.isConfigured) {
        throw const ValidationException('Set the server address first.');
      }
      final auth = await attempt();
      await ref.read(vaultSessionProvider.notifier).establish(auth, method);
    });
  }
}
