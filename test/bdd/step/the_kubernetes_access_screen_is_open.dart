import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/app/providers/core_providers.dart';
import 'package:transikey/core/models/auth_response.dart';
import 'package:transikey/core/security/secret_store.dart';
import 'package:transikey/features/auth/domain/vault_session.dart';
import 'package:transikey/features/auth/presentation/session_provider.dart';
import 'package:transikey/features/kubernetes/presentation/kubernetes_screen.dart';
import 'package:transikey/features/settings/domain/app_settings.dart';
import 'package:transikey/features/settings/presentation/settings_provider.dart';

import 'kubernetes_world.dart';

/// Usage: the Kubernetes access screen is open
Future<void> theKubernetesAccessScreenIsOpen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final store = InMemorySecretStore();
  await store.write(
    'transikey.settings',
    jsonEncode(
      const AppSettings(
        vaultAddr: 'https://bao.test:8200',
        inactivityTimeoutSeconds: 0, // No idle timer left pending.
      ).toJson(),
    ),
  );

  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: [
      apiClientProvider.overrideWithValue(KubernetesWorld.server),
      secretStoreProvider.overrideWithValue(store),
      clipboardGuardProvider.overrideWithValue(KubernetesWorld.clipboard),
    ],
  );
  addTearDown(container.dispose);
  // Roles are listed for a signed-in session only.
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

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: KubernetesScreen())),
    ),
  );
  await tester.pumpAndSettle();
}
