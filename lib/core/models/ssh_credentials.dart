import 'package:freezed_annotation/freezed_annotation.dart';

import 'lease_info.dart';

part 'ssh_credentials.freezed.dart';

/// One-time SSH password issued by `ssh/creds/{role}`.
@freezed
abstract class SshCredentials with _$SshCredentials {
  const SshCredentials._();

  const factory SshCredentials({
    required String role,
    required String username,
    required String otp,
    required String ip,
    required int port,
    required LeaseInfo lease,
  }) = _SshCredentials;

  @override
  String toString() => 'SshCredentials(role: $role, ip: $ip, otp: ***)';
}

/// Certificate issued by `ssh/sign/{role}`.
@freezed
abstract class SignedCertificate with _$SignedCertificate {
  const SignedCertificate._();

  const factory SignedCertificate({
    required String role,
    required String serialNumber,
    required String signedKey,
  }) = _SignedCertificate;

  @override
  String toString() =>
      'SignedCertificate(role: $role, serialNumber: $serialNumber)';
}

/// Response of `ssh/get-attempt-token`.
@freezed
abstract class SshAttemptToken with _$SshAttemptToken {
  const SshAttemptToken._();

  const factory SshAttemptToken({
    required String token,
    required Map<String, String> metadata,
    required Duration leaseDuration,
  }) = _SshAttemptToken;

  @override
  String toString() => 'SshAttemptToken(token: ***)';
}
