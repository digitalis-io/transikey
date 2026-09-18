import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/app/providers/core_providers.dart';
import 'package:transikey/core/errors/vault_exception.dart';
import 'package:transikey/core/models/auth_response.dart';
import 'package:transikey/core/models/wrapped_secret.dart';
import 'package:transikey/features/auth/domain/vault_session.dart';
import 'package:transikey/features/auth/presentation/session_provider.dart';
import 'package:transikey/features/settings/presentation/settings_provider.dart';
import 'package:transikey/core/security/secret_store.dart';
import 'package:transikey/features/settings/domain/app_settings.dart';
import 'package:transikey/features/sharing/presentation/sharing_screen.dart';

import 'sharing_world.dart';

/// Usage: the secret sharing screen is open
Future<void> theSecretSharingScreenIsOpen(
  WidgetTester tester, {
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  registerFallbackValue(Duration.zero);
  final server = FakeSharingServer();
  when(() => server.wrapSecret(any(), any())).thenAnswer((call) async {
    final payload = call.positionalArguments[0] as Map<String, dynamic>;
    if (payload.isEmpty) throw const ValidationException('Nothing to wrap.');
    return WrappedSecret(
      token: 'wrapping-token-1',
      accessor: 'accessor-1',
      ttl: const Duration(minutes: 30),
      creationTime: DateTime.utc(2026),
    );
  });
  when(() => server.cubbyholeList(any())).thenAnswer((_) async => const []);

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

  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: [
      apiClientProvider.overrideWithValue(server),
      secretStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  SharingWorld.server = server;
  SharingWorld.container = container;

  if (signedIn) {
    await container.read(settingsProvider.future);
    await container
        .read(vaultSessionProvider.notifier)
        .establish(
          const AuthResponse(
            clientToken: 'test-token',
            accessor: 'test-accessor',
            policies: ['transikey'],
            leaseDuration: Duration.zero, // Never expires: no pending timers.
            renewable: false,
            displayName: 'demo',
          ),
          AuthMethod.userpass,
        );
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: SharingScreen())),
    ),
  );
  await tester.pumpAndSettle();
}
