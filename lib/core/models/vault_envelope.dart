import 'package:freezed_annotation/freezed_annotation.dart';

part 'vault_envelope.freezed.dart';
part 'vault_envelope.g.dart';

/// Standard response envelope returned by the Vault/OpenBao HTTP API.
@freezed
abstract class VaultEnvelope with _$VaultEnvelope {
  const VaultEnvelope._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory VaultEnvelope({
    String? requestId,
    @Default('') String leaseId,
    @Default(0) int leaseDuration,
    @Default(false) bool renewable,
    Map<String, dynamic>? data,
    Map<String, dynamic>? wrapInfo,
    Map<String, dynamic>? auth,
    List<String>? warnings,
  }) = _VaultEnvelope;

  factory VaultEnvelope.fromJson(Map<String, dynamic> json) =>
      _$VaultEnvelopeFromJson(json);

  Duration get leaseTtl => Duration(seconds: leaseDuration);

  @override
  String toString() =>
      'VaultEnvelope(requestId: $requestId, leaseId: ${leaseId.isEmpty ? '-' : '<set>'})';
}
