/// Base type for every failure surfaced by the Vault/OpenBao client.
///
/// [message] is safe to show in the UI. [errors] holds the server supplied
/// error strings after redaction and is intended for diagnostics only.
class VaultException implements Exception {
  const VaultException(this.message, {this.statusCode, this.errors = const []});

  final String message;
  final int? statusCode;
  final List<String> errors;

  @override
  String toString() =>
      '$runtimeType(${statusCode ?? '-'}): $message'
      '${errors.isEmpty ? '' : ' [${errors.join('; ')}]'}';
}

/// Credentials were rejected or the token is no longer valid.
class AuthenticationException extends VaultException {
  const AuthenticationException(
    super.message, {
    super.statusCode,
    super.errors,
  });
}

/// The token is valid but its policies do not allow the operation.
class PermissionDeniedException extends VaultException {
  const PermissionDeniedException(
    super.message, {
    super.statusCode,
    super.errors,
  });
}

/// The lease does not exist any more (expired or revoked).
class LeaseExpiredException extends VaultException {
  const LeaseExpiredException(super.message, {super.statusCode, super.errors});
}

/// The server could not be reached (DNS, refused, timeout).
class NetworkException extends VaultException {
  const NetworkException(super.message, {super.statusCode, super.errors});
}

/// TLS handshake or certificate validation failed.
class TlsException extends VaultException {
  const TlsException(super.message, {super.statusCode, super.errors});
}

/// The request was malformed or the input failed local validation.
class ValidationException extends VaultException {
  const ValidationException(super.message, {super.statusCode, super.errors});
}

/// The path, role or mount does not exist.
class NotFoundException extends VaultException {
  const NotFoundException(super.message, {super.statusCode, super.errors});
}

/// The server failed (5xx), is sealed, or is rate limiting.
class ServerException extends VaultException {
  const ServerException(super.message, {super.statusCode, super.errors});
}
