import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/app/providers/core_providers.dart';
import 'package:transikey/core/api/vault_api_client.dart';
import 'package:transikey/core/models/database_credentials.dart';
import 'package:transikey/core/models/lease_info.dart';
import 'package:transikey/core/security/secret_store.dart';
import 'package:transikey/features/database/presentation/database_screen.dart';
import 'package:transikey/features/settings/domain/app_settings.dart';

class _FakeServer extends Mock implements VaultApiClient {}

/// Usage: the database credentials screen is open
Future<void> theDatabaseCredentialsScreenIsOpen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final server = _FakeServer();
  when(
    () => server.listDatabaseRoles(),
  ).thenAnswer((_) async => const ['readonly', 'short-lived']);
  when(() => server.getDatabaseCredentials(any())).thenAnswer(
    (call) async => DatabaseCredentials(
      role: call.positionalArguments.first as String,
      username: 'v-token-${call.positionalArguments.first}',
      password: 'generated-password',
      lease: const LeaseInfo(
        leaseId: 'database/creds/x/1',
        leaseDuration: Duration(minutes: 10),
        renewable: true,
      ),
    ),
  );

  final store = InMemorySecretStore();
  await store.write(
    'transikey.settings',
    jsonEncode(const AppSettings(vaultAddr: 'https://bao.test:8200').toJson()),
  );

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, __) => null,
      overrides: [
        apiClientProvider.overrideWithValue(server),
        secretStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: Scaffold(body: DatabaseScreen())),
    ),
  );
  await tester.pumpAndSettle();
}
