import 'dart:io' as io;

import 'package:dio/dio.dart';

import '../errors/vault_exception.dart';
import '../utils/redaction.dart';

/// Converts transport and HTTP failures into the [VaultException] hierarchy.
abstract final class ErrorMapper {
  static VaultException map(Object error) {
    if (error is VaultException) return error;
    if (error is! DioException) {
      return VaultException(
        'Unexpected error.',
        errors: [Redaction.text(error.toString())],
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkException('The server did not respond in time.');
      case DioExceptionType.badCertificate:
        return const TlsException(
          'The server certificate could not be verified.',
        );
      case DioExceptionType.cancel:
        return const NetworkException('The request was cancelled.');
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        final inner = error.error;
        if (inner is io.HandshakeException ||
            inner is io.CertificateException ||
            inner is io.TlsException) {
          return TlsException(
            'TLS handshake failed. Check the CA certificate or TLS settings.',
            errors: [Redaction.text(inner.toString())],
          );
        }
        return NetworkException(
          'Cannot reach the server. Check the address and your network.',
          errors: [if (inner != null) Redaction.text(inner.toString())],
        );
      case DioExceptionType.badResponse:
        return _fromResponse(error.response!, error.requestOptions.path);
    }
  }

  static VaultException _fromResponse(Response<dynamic> response, String path) {
    final status = response.statusCode ?? 0;
    final errors = _serverErrors(response.data);
    final joined = errors.join(' ').toLowerCase();
    final isAuthPath =
        path.contains('/login') || path.endsWith('auth/token/lookup-self');

    if (joined.contains('lease not found') ||
        joined.contains('lease is not renewable') ||
        joined.contains('lease expired')) {
      return LeaseExpiredException(
        'The lease has expired or was revoked.',
        statusCode: status,
        errors: errors,
      );
    }

    switch (status) {
      case 400:
        if (isAuthPath) {
          return AuthenticationException(
            'Login failed. Check your credentials.',
            statusCode: status,
            errors: errors,
          );
        }
        return ValidationException(
          errors.isEmpty ? 'The request was rejected.' : errors.first,
          statusCode: status,
          errors: errors,
        );
      case 401:
        return AuthenticationException(
          'Authentication required.',
          statusCode: status,
          errors: errors,
        );
      case 403:
        if (isAuthPath) {
          return AuthenticationException(
            'The token is invalid or has expired.',
            statusCode: status,
            errors: errors,
          );
        }
        return PermissionDeniedException(
          'Permission denied. Your policies do not allow this operation.',
          statusCode: status,
          errors: errors,
        );
      case 404:
        return NotFoundException(
          'Not found. Check the mount path and role name.',
          statusCode: status,
          errors: errors,
        );
      case 429:
        return ServerException(
          'The server is rate limiting requests. Try again shortly.',
          statusCode: status,
          errors: errors,
        );
      case 503:
        return ServerException(
          'The server is sealed or unavailable.',
          statusCode: status,
          errors: errors,
        );
    }
    if (status >= 300 && status < 400) {
      return NetworkException(
        'The server redirected the request. Use the address of the active '
        'node; redirects are not followed to protect your token.',
        statusCode: status,
        errors: errors,
      );
    }
    if (status >= 500) {
      return ServerException(
        'The server reported an internal error.',
        statusCode: status,
        errors: errors,
      );
    }
    return VaultException(
      'Unexpected response (HTTP $status).',
      statusCode: status,
      errors: errors,
    );
  }

  static List<String> _serverErrors(Object? body) {
    if (body is Map && body['errors'] is List) {
      return (body['errors'] as List)
          .map((e) => Redaction.text(e.toString()))
          .toList();
    }
    return const [];
  }
}
