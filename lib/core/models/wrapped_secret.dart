import 'package:freezed_annotation/freezed_annotation.dart';

part 'wrapped_secret.freezed.dart';

/// Response-wrapping token produced by `sys/wrapping/wrap`.
@freezed
abstract class WrappedSecret with _$WrappedSecret {
  const WrappedSecret._();

  const factory WrappedSecret({
    required String token,
    required String accessor,
    required Duration ttl,
    required DateTime creationTime,
    @Default('') String creationPath,
  }) = _WrappedSecret;

  DateTime get expiresAt => creationTime.add(ttl);

  @override
  String toString() => 'WrappedSecret(accessor: $accessor, token: ***)';
}

/// Payload returned by `sys/wrapping/unwrap`.
@freezed
abstract class UnwrappedSecret with _$UnwrappedSecret {
  const UnwrappedSecret._();

  const factory UnwrappedSecret({
    required Map<String, dynamic> data,
    @Default('') String requestId,
    @Default('') String leaseId,
    @Default(Duration.zero) Duration leaseDuration,
    @Default(false) bool renewable,
    @Default([]) List<String> warnings,
  }) = _UnwrappedSecret;

  @override
  String toString() => 'UnwrappedSecret(keys: ${data.keys.toList()})';
}
