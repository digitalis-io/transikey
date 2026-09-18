import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/core/api/vault_api_client.dart';
import 'package:transikey/core/errors/vault_exception.dart';
import 'package:transikey/core/models/auth_response.dart';
import 'package:transikey/features/auth/data/oidc_login_flow.dart';

class _MockClient extends Mock implements VaultApiClient {}

const _auth = AuthResponse(
  clientToken: 'oidc-token',
  accessor: 'acc',
  policies: ['default'],
  leaseDuration: Duration(hours: 1),
  renewable: true,
  displayName: 'alice@example.com',
);

/// Plays the identity provider: redirects the "browser" to the callback.
Future<void> _hitCallback(int port, Map<String, String> query) async {
  final http = HttpClient();
  final request = await http.getUrl(
    Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: port,
      path: '/oidc/callback',
      queryParameters: query,
    ),
  );
  await (await request.close()).drain<void>();
  http.close();
}

void main() {
  const port = 18250; // Not 8250: a developer may have a real login open.
  late _MockClient client;

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    client = _MockClient();
    when(
      () => client.oidcAuthUrl(
        role: any(named: 'role'),
        redirectUri: any(named: 'redirectUri'),
        clientNonce: any(named: 'clientNonce'),
      ),
    ).thenAnswer(
      (_) async => Uri.parse('https://idp.example/authorize?state=st-123'),
    );
    when(
      () => client.oidcCallback(
        state: any(named: 'state'),
        code: any(named: 'code'),
        clientNonce: any(named: 'clientNonce'),
      ),
    ).thenAnswer((_) async => _auth);
  });

  OidcLoginFlow flow(Map<String, String> callbackQuery, {Duration? timeout}) =>
      OidcLoginFlow(
        client: client,
        port: port,
        timeout: timeout ?? const Duration(seconds: 5),
        openBrowser: (url) async {
          if (callbackQuery.isNotEmpty) {
            // Fire and forget, as a real browser would.
            // ignore: unawaited_futures
            _hitCallback(port, callbackQuery);
          }
          return true;
        },
      );

  test(
    'a matching callback is exchanged for a token with the same nonce',
    () async {
      final auth = await flow({'state': 'st-123', 'code': 'c0de'}).run('dev');

      expect(auth, _auth);
      final sent =
          verify(
                () => client.oidcAuthUrl(
                  role: 'dev',
                  redirectUri: Uri.parse(
                    'http://localhost:$port/oidc/callback',
                  ),
                  clientNonce: captureAny(named: 'clientNonce'),
                ),
              ).captured.single
              as String;
      expect(sent.length, greaterThanOrEqualTo(24));
      verify(
        () => client.oidcCallback(
          state: 'st-123',
          code: 'c0de',
          clientNonce: sent,
        ),
      ).called(1);
    },
  );

  test('a callback with a foreign state is rejected', () async {
    await expectLater(
      flow({'state': 'someone-else', 'code': 'c0de'}).run(''),
      throwsA(isA<AuthenticationException>()),
    );
    verifyNever(
      () => client.oidcCallback(
        state: any(named: 'state'),
        code: any(named: 'code'),
        clientNonce: any(named: 'clientNonce'),
      ),
    );
  });

  test('a callback without a code is rejected', () async {
    await expectLater(
      flow({'state': 'st-123'}).run(''),
      throwsA(isA<AuthenticationException>()),
    );
  });

  test('a provider error is reported', () async {
    await expectLater(
      flow({
        'error': 'access_denied',
        'error_description': 'User said no',
      }).run(''),
      throwsA(
        isA<AuthenticationException>().having(
          (e) => e.errors,
          'errors',
          contains('User said no'),
        ),
      ),
    );
  });

  test('no callback at all times out', () async {
    await expectLater(
      flow(const {}, timeout: const Duration(milliseconds: 300)).run(''),
      throwsA(isA<AuthenticationException>()),
    );
  });

  test('the port is released after every attempt', () async {
    await flow({'state': 'st-123', 'code': 'c0de'}).run('');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    await server.close();
  });

  test('a busy port is a clear validation error', () async {
    final blocker = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    addTearDown(() => blocker.close(force: true));
    await expectLater(
      flow(const {}).run(''),
      throwsA(isA<ValidationException>()),
    );
  });
}
