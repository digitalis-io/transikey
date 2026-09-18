import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/api/dio_vault_api_client.dart';
import 'package:transikey/core/api/vault_connection_config.dart';
import 'package:transikey/core/errors/vault_exception.dart';

/// Fails the test if a request leaves the client.
class _NoNetwork extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) =>
      fail('Request sent: ${options.path}');
}

void main() {
  final client = DioVaultApiClient(
    dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'))
      ..interceptors.add(_NoNetwork()),
    config: const VaultConnectionConfig(address: 'http://127.0.0.1:1'),
  );

  // Mount and role names come from the server as well as from the user.
  for (final (mount, role) in [
    ('..', 'readonly'),
    ('database/../sys', 'readonly'),
    ('database', '..'),
    ('database', '../../sys/raw'),
    ('database', 'a//b'),
    ('./database', 'readonly'),
  ]) {
    test('"$mount" / "$role" never becomes a request', () async {
      await expectLater(
        client.getDatabaseCredentials(mount, role),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        client.describeDatabaseRole(mount, role),
        throwsA(isA<ValidationException>()),
      );
    });
  }

  test('a mount made of dots only is refused when listing roles', () async {
    await expectLater(
      client.listDatabaseRoles('../auth/token'),
      throwsA(isA<ValidationException>()),
    );
  });
}
