import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/app/providers/core_providers.dart';
import 'package:transikey/core/api/vault_api_client.dart';
import 'package:transikey/core/errors/vault_exception.dart';
import 'package:transikey/core/models/auth_response.dart';
import 'package:transikey/core/security/secret_store.dart';
import 'package:transikey/core/utils/cli_environment.dart';
import 'package:transikey/features/auth/presentation/auth_screen.dart';
import 'package:transikey/features/settings/domain/app_settings.dart';

class _FakeServer extends Mock implements VaultApiClient {}

/// The only account the fake server accepts.
const _validUser = 'demo';
const _validPassword = 'good-password';

/// Usage: the app is connected to a test server
Future<void> theAppIsConnectedToATestServer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final server = _FakeServer();
  Future<AuthResponse> login(Invocation call) async {
    final username = call.positionalArguments[0] as String;
    final password = call.positionalArguments[1] as String;
    if (username != _validUser || password != _validPassword) {
      throw const AuthenticationException(
        'Login failed. Check your credentials.',
      );
    }
    return AuthResponse(
      clientToken: 'test-token',
      accessor: 'test-accessor',
      policies: const ['default', 'transikey'],
      leaseDuration: Duration.zero, // Never expires: no timers left pending.
      renewable: false,
      displayName: username,
    );
  }

  when(() => server.loginWithUserpass(any(), any())).thenAnswer(login);
  when(() => server.loginWithLdap(any(), any())).thenAnswer(login);
  when(() => server.revokeSelf()).thenAnswer((_) async {});

  final store = InMemorySecretStore();
  await store.write(
    'transikey.settings',
    jsonEncode(
      const AppSettings(
        vaultAddr: 'https://bao.test:8200',
        inactivityTimeoutSeconds: 0,
      ).toJson(),
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, __) => null,
      overrides: [
        apiClientProvider.overrideWithValue(server),
        secretStoreProvider.overrideWithValue(store),
        // Deterministic: the developer's own shell must not leak in.
        cliEnvironmentProvider.overrideWithValue(
          CliEnvironment.from(const {
            'BAO_ADDR': 'https://bao.cli.example:8200',
            'BAO_NAMESPACE': 'team-cli',
            'BAO_TOKEN': 'cli-token',
          }, fileExists: (_) => false),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: AuthScreen())),
    ),
  );
  await tester.pumpAndSettle();
}
