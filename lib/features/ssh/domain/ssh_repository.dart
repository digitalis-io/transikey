import '../../../core/models/ssh_credentials.dart';

abstract class SshRepository {
  Future<List<String>> listRoles();

  Future<SshCredentials> requestOtp(
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

  Future<SshAttemptToken> requestAttemptToken(Map<String, dynamic> params);
}

/// Outcome of the last SSH operation.
sealed class SshResult {
  const SshResult();
}

class SshOtpResult extends SshResult {
  const SshOtpResult(this.credentials);
  final SshCredentials credentials;
}

class SshSignedResult extends SshResult {
  const SshSignedResult(this.certificate);
  final SignedCertificate certificate;
}

class SshAttemptTokenResult extends SshResult {
  const SshAttemptTokenResult(this.token, this.issuedAt);
  final SshAttemptToken token;
  final DateTime issuedAt;
}
