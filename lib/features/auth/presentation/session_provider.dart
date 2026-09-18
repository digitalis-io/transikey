import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/errors/vault_exception.dart';
import '../../../core/models/auth_response.dart';
import '../../settings/presentation/settings_provider.dart';
import '../data/vault_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/vault_session.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => VaultAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secretStoreProvider),
    ref.watch(browserLauncherProvider),
  ),
);

final vaultSessionProvider =
    NotifierProvider<VaultSessionNotifier, SessionState>(
      VaultSessionNotifier.new,
    );

/// True while a token is in memory. Server reads watch this, so they never
/// run without a token (signed out, or locked under the lock overlay) and
/// run again as soon as the session starts or is unlocked.
final sessionActiveProvider = Provider<bool>(
  (ref) => ref.watch(vaultSessionProvider) is SessionAuthenticated,
);

/// Owns the session lifecycle: establish, renew, expire, lock and logout.
class VaultSessionNotifier extends Notifier<SessionState> {
  Timer? _expiryTimer;
  Timer? _renewTimer;
  Timer? _idleTimer;

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  SessionState build() {
    ref.onDispose(_cancelTimers);
    // Restart the idle countdown when the timeout setting changes.
    ref.listen(
      settingsProvider.select((s) => s.value?.inactivityTimeoutSeconds),
      (_, __) => registerActivity(),
    );
    Future.microtask(_restore);
    return const SessionUnauthenticated();
  }

  /// Called after a successful login.
  Future<void> establish(AuthResponse auth, AuthMethod method) async {
    final session = _sessionFrom(auth, method);
    ref.read(tokenHolderProvider).set(auth.clientToken);
    await _repository.persist(auth.clientToken, session);
    _activate(session);
  }

  Future<void> renew() async {
    final current = state;
    if (current is! SessionAuthenticated) return;
    final auth = await _repository.renewSelf();
    final session = _sessionFrom(
      auth,
      current.session.method,
    ).copyWith(displayName: current.session.displayName);
    await _repository.persist(auth.clientToken, session);
    _activate(session);
  }

  /// Drops the token from memory. The keystore copy stays for [unlock].
  void lock() {
    final current = state;
    if (current is! SessionAuthenticated) return;
    _cancelTimers();
    ref.read(tokenHolderProvider).clear();
    state = SessionLocked(current.session);
  }

  /// Unlocks with a biometric prompt. Returns false when the prompt was
  /// dismissed or biometrics are unavailable.
  Future<bool> unlock() async {
    final current = state;
    if (current is! SessionLocked) return false;
    final settings = ref.read(settingsProvider).value;
    final biometrics = ref.read(biometricAuthProvider);
    if (settings?.biometricUnlock != true || !await biometrics.isAvailable()) {
      return false;
    }
    if (!await biometrics.authenticate('Unlock your Transikey session')) {
      return false;
    }
    final stored = await _repository.restore();
    if (stored == null) {
      await logout(revoke: false, reason: 'Stored session not found.');
      return false;
    }
    try {
      final auth = await _repository.loginWithToken(stored.token);
      await establish(auth, stored.session.method);
      return true;
    } on AuthenticationException {
      await logout(revoke: false, reason: 'Token expired.');
      return false;
    }
  }

  Future<void> logout({bool revoke = true, String? reason}) async {
    _cancelTimers();
    final holder = ref.read(tokenHolderProvider);
    // Only revoke tokens this app minted through a login. A token the user
    // pasted in (root, CI, shared) belongs to them and must stay valid.
    final current = state;
    final method = switch (current) {
      SessionAuthenticated(:final session) => session.method,
      SessionLocked(:final session) => session.method,
      SessionUnauthenticated() => null,
    };
    if (method == AuthMethod.token) revoke = false;
    if (revoke && !holder.hasToken) {
      // Locked: the token only lives in the keystore.
      final stored = await _repository.restore();
      if (stored != null) holder.set(stored.token);
    }
    if (revoke && holder.hasToken) {
      try {
        await _repository.revokeSelf();
      } on VaultException catch (e) {
        ref.read(loggerProvider).warning('session.revoke.failed: ${e.message}');
      }
    }
    holder.clear();
    await _repository.clear();
    await ref.read(clipboardGuardProvider).clearIfOurs();
    state = SessionUnauthenticated(reason: reason);
  }

  /// Any user input resets the inactivity countdown.
  void registerActivity() {
    _idleTimer?.cancel();
    if (state is! SessionAuthenticated) return;
    final timeout =
        ref.read(settingsProvider).value?.inactivityTimeout ??
        const Duration(minutes: 5);
    if (timeout > Duration.zero) _idleTimer = Timer(timeout, lock);
  }

  Future<void> _restore() async {
    final stored = await _repository.restore();
    if (stored == null || !ref.mounted || state is SessionAuthenticated) return;
    final settings = await ref.read(settingsProvider.future);
    if (settings.biometricUnlock) {
      state = SessionLocked(stored.session);
      return;
    }
    try {
      final auth = await _repository.loginWithToken(stored.token);
      await establish(auth, stored.session.method);
    } on AuthenticationException {
      await logout(revoke: false, reason: 'Token expired.');
    } on VaultException {
      // Server unreachable: keep the stored token, stay signed out for now.
    }
  }

  void _activate(VaultSession session) {
    _cancelTimers();
    state = SessionAuthenticated(session);
    if (!session.neverExpires) {
      final ttl = Duration(seconds: session.ttlSeconds);
      _expiryTimer = Timer(
        ttl,
        () => logout(revoke: false, reason: 'Token expired.'),
      );
      if (session.renewable) {
        _renewTimer = Timer(ttl * (2 / 3), () async {
          try {
            await renew();
          } on AuthenticationException {
            // The token was revoked or expired early: end the session now.
            await logout(revoke: false, reason: 'Token expired.');
          } on VaultException catch (e) {
            ref
                .read(loggerProvider)
                .warning('session.renew.failed: ${e.message}');
          }
        });
      }
    }
    registerActivity();
  }

  VaultSession _sessionFrom(AuthResponse auth, AuthMethod method) =>
      VaultSession(
        method: method,
        displayName: auth.displayName.isEmpty ? method.name : auth.displayName,
        policies: auth.policies,
        issuedAt: DateTime.now(),
        ttlSeconds: auth.leaseDuration.inSeconds,
        renewable: auth.renewable,
      );

  void _cancelTimers() {
    _expiryTimer?.cancel();
    _renewTimer?.cancel();
    _idleTimer?.cancel();
  }
}
