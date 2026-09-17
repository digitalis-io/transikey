import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/api/error_mapper.dart';
import 'package:transikey/core/errors/vault_exception.dart';

DioException _response(
  int status,
  String path, [
  List<String> errors = const [],
]) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: {'errors': errors},
    ),
  );
}

void main() {
  test('403 on a secrets path is permission denied', () {
    final e = ErrorMapper.map(_response(403, '/v1/database/creds/ro'));
    expect(e, isA<PermissionDeniedException>());
    expect(e.statusCode, 403);
  });

  test('403 on lookup-self is an authentication failure', () {
    expect(
      ErrorMapper.map(_response(403, '/v1/auth/token/lookup-self')),
      isA<AuthenticationException>(),
    );
  });

  test('400 on a login path is an authentication failure', () {
    expect(
      ErrorMapper.map(
        _response(400, '/v1/auth/userpass/login/bob', [
          'invalid username or password',
        ]),
      ),
      isA<AuthenticationException>(),
    );
  });

  test('400 elsewhere is a validation error carrying the server message', () {
    final e = ErrorMapper.map(
      _response(400, '/v1/ssh/creds/otp', ['missing ip']),
    );
    expect(e, isA<ValidationException>());
    expect(e.message, 'missing ip');
  });

  test('lease not found maps to LeaseExpiredException', () {
    expect(
      ErrorMapper.map(
        _response(400, '/v1/sys/leases/renew', ['lease not found']),
      ),
      isA<LeaseExpiredException>(),
    );
  });

  test('404 and 5xx map to not-found and server errors', () {
    expect(ErrorMapper.map(_response(404, '/v1/x')), isA<NotFoundException>());
    expect(ErrorMapper.map(_response(503, '/v1/x')), isA<ServerException>());
    expect(ErrorMapper.map(_response(500, '/v1/x')), isA<ServerException>());
  });

  test('a redirect is reported, never followed', () {
    final e = ErrorMapper.map(_response(307, '/v1/database/creds/ro'));
    expect(e, isA<NetworkException>());
    expect(e.message, contains('redirected'));
  });

  test('server error strings are redacted', () {
    final e = ErrorMapper.map(
      _response(500, '/v1/x', ['failed for token hvs.CAESIJ1234567890abcdef']),
    );
    expect(e.errors.single, isNot(contains('CAESIJ')));
  });

  test('timeouts and refused connections are network errors', () {
    final options = RequestOptions(path: '/v1/sys/health');
    expect(
      ErrorMapper.map(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      ),
      isA<NetworkException>(),
    );
    expect(
      ErrorMapper.map(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('refused'),
        ),
      ),
      isA<NetworkException>(),
    );
  });

  test('certificate and handshake failures are TLS errors', () {
    final options = RequestOptions(path: '/v1/sys/health');
    expect(
      ErrorMapper.map(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badCertificate,
        ),
      ),
      isA<TlsException>(),
    );
    expect(
      ErrorMapper.map(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const HandshakeException('bad cert'),
        ),
      ),
      isA<TlsException>(),
    );
  });

  test('VaultException passes through unchanged', () {
    const original = ValidationException('x');
    expect(ErrorMapper.map(original), same(original));
  });
}
