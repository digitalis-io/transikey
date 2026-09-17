import 'package:freezed_annotation/freezed_annotation.dart';

part 'vault_session.freezed.dart';
part 'vault_session.g.dart';

enum AuthMethod { token, userpass, approle }

/// Non-secret description of the active login. The token itself lives in
/// `TokenHolder` (memory) and the OS keystore, never in this object.
@freezed
abstract class VaultSession with _$VaultSession {
  const VaultSession._();

  const factory VaultSession({
    required AuthMethod method,
    required String displayName,
    required List<String> policies,
    required DateTime issuedAt,
    required int ttlSeconds,
    required bool renewable,
  }) = _VaultSession;

  factory VaultSession.fromJson(Map<String, dynamic> json) =>
      _$VaultSessionFromJson(json);

  /// Tokens with a zero TTL (root tokens) never expire.
  bool get neverExpires => ttlSeconds <= 0;

  DateTime? get expiresAt =>
      neverExpires ? null : issuedAt.add(Duration(seconds: ttlSeconds));

  Duration? remaining(DateTime now) => expiresAt?.difference(now);
}

sealed class SessionState {
  const SessionState();
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.reason});

  /// Why the previous session ended, for example "Token expired".
  final String? reason;
}

/// A token is stored but must be unlocked before use.
class SessionLocked extends SessionState {
  const SessionLocked(this.session);
  final VaultSession session;
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.session);
  final VaultSession session;
}
