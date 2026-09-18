import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_response.freezed.dart';

/// Result of a login or token lookup.
@freezed
abstract class AuthResponse with _$AuthResponse {
  const AuthResponse._();

  const factory AuthResponse({
    required String clientToken,
    required String accessor,
    required List<String> policies,
    required Duration leaseDuration,
    required bool renewable,
    @Default('') String displayName,
    @Default({}) Map<String, String> metadata,
  }) = _AuthResponse;

  /// Parses the `auth` block of a login response.
  factory AuthResponse.fromAuthBlock(Map<String, dynamic> auth) => AuthResponse(
    clientToken: auth['client_token'] as String? ?? '',
    accessor: auth['accessor'] as String? ?? '',
    policies: _strings(auth['policies']),
    leaseDuration: Duration(seconds: _int(auth['lease_duration'])),
    renewable: auth['renewable'] as bool? ?? false,
    displayName:
        (auth['metadata'] as Map?)?['username'] as String? ??
        (auth['metadata'] as Map?)?['role_name'] as String? ??
        '',
    metadata: _stringMap(auth['metadata']),
  );

  /// Parses the `data` block of `auth/token/lookup-self`.
  factory AuthResponse.fromLookup(String token, Map<String, dynamic> data) =>
      AuthResponse(
        clientToken: token,
        accessor: data['accessor'] as String? ?? '',
        policies: _strings(data['policies']),
        leaseDuration: Duration(seconds: _int(data['ttl'])),
        renewable: data['renewable'] as bool? ?? false,
        displayName: data['display_name'] as String? ?? '',
        metadata: _stringMap(data['meta']),
      );

  @override
  String toString() =>
      'AuthResponse(displayName: $displayName, policies: $policies, clientToken: ***)';
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

List<String> _strings(Object? v) =>
    v is List ? v.map((e) => '$e').toList() : const [];

Map<String, String> _stringMap(Object? v) =>
    v is Map ? v.map((k, e) => MapEntry('$k', '$e')) : const {};
