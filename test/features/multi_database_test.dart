import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/app/providers/core_providers.dart';
import 'package:transikey/core/api/vault_api_client.dart';
import 'package:transikey/core/errors/vault_exception.dart';
import 'package:transikey/core/models/auth_response.dart';
import 'package:transikey/core/models/database_credentials.dart';
import 'package:transikey/core/models/lease_info.dart';
import 'package:transikey/core/security/secret_store.dart';
import 'package:transikey/core/utils/db_connect_command.dart';
import 'package:transikey/core/utils/db_target_detection.dart';
import 'package:transikey/features/auth/domain/vault_session.dart';
import 'package:transikey/features/auth/presentation/session_provider.dart';
import 'package:transikey/features/database/presentation/database_credentials_card.dart';
import 'package:transikey/features/database/presentation/database_provider.dart';
import 'package:transikey/features/settings/domain/app_settings.dart';
import 'package:transikey/features/settings/domain/server_profile.dart';
import 'package:transikey/features/settings/presentation/settings_provider.dart';

class _MockClient extends Mock implements VaultApiClient {}

DatabaseCredentials _creds(String mount, String role, [String pw = 'pw']) =>
    DatabaseCredentials(
      mount: mount,
      role: role,
      username: 'u-$role',
      password: pw,
      lease: LeaseInfo(
        leaseId: '$mount/creds/$role/1',
        leaseDuration: const Duration(minutes: 5),
        renewable: true,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockClient client;
  late ProviderContainer container;

  Future<void> start(AppSettings settings) async {
    client = _MockClient();
    container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [
        apiClientProvider.overrideWithValue(client),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);
    await container.read(settingsProvider.notifier).save(settings);
    await container
        .read(vaultSessionProvider.notifier)
        .establish(
          const AuthResponse(
            clientToken: 'test-token',
            accessor: 'acc',
            policies: ['transikey'],
            leaseDuration: Duration.zero,
            renewable: false,
            displayName: 'demo',
          ),
          AuthMethod.userpass,
        );
  }

  const base = AppSettings(
    vaultAddr: 'http://127.0.0.1:8200',
    inactivityTimeoutSeconds: 0,
  );

  group('mounts', () {
    test(
      'only database engines are kept from what the server reveals',
      () async {
        await start(base);
        when(client.listSecretMounts).thenAnswer(
          (_) async => const {
            'postgres': 'database',
            'cass001': 'database',
            'ssh': 'ssh',
            'cubbyhole': 'cubbyhole',
          },
        );
        expect(await container.read(databaseMountsProvider.future), [
          'cass001',
          'postgres',
        ]);
      },
    );

    test('the configured list is used when discovery is denied', () async {
      await start(base.copyWith(databaseMount: ' /cass001/, cass002 ,, '));
      when(
        client.listSecretMounts,
      ).thenThrow(const PermissionDeniedException('Permission denied.'));
      expect(await container.read(databaseMountsProvider.future), [
        'cass001',
        'cass002',
      ]);
    });

    test(
      'the configured list is used when no database mount is revealed',
      () async {
        await start(base);
        when(
          client.listSecretMounts,
        ).thenAnswer((_) async => const {'ssh': 'ssh'});
        expect(await container.read(databaseMountsProvider.future), [
          'database',
        ]);
      },
    );

    test('an empty setting falls back to the default mount', () {
      expect(const AppSettings(databaseMount: ' , ').databaseMountList, [
        'database',
      ]);
    });
  });

  group('roles', () {
    test('a mount that cannot be listed does not fail the others', () async {
      await start(base);
      when(client.listSecretMounts).thenAnswer(
        (_) async => const {'cass001': 'database', 'locked': 'database'},
      );
      when(
        () => client.listDatabaseRoles('cass001'),
      ).thenAnswer((_) async => const ['operator']);
      when(() => client.listDatabaseRoles('locked')).thenAnswer(
        (_) async => throw const PermissionDeniedException('Denied.'),
      );

      final groups = await container.read(databaseRolesProvider.future);
      expect(
        [for (final g in groups) '${g.name}: ${g.error ?? g.roles}'],
        ['cass001: [operator]', 'locked: Denied.'],
      );
    });
  });

  group('credentials', () {
    test('are issued from the mount of the role', () async {
      await start(base);
      when(
        () => client.getDatabaseCredentials('cass002', 'readonly'),
      ).thenAnswer((_) async => _creds('cass002', 'readonly'));
      await container.read(databaseCredentialsProvider.notifier).request((
        mount: 'cass002',
        role: 'readonly',
      ));

      expect(
        container.read(databaseCredentialsProvider).value?.key,
        'cass002/readonly',
      );
    });

    test('an answer that arrives after a clear is dropped', () async {
      await start(base);
      final pending = Completer<DatabaseCredentials>();
      when(
        () => client.getDatabaseCredentials('database', 'slow'),
      ).thenAnswer((_) => pending.future);
      final notifier = container.read(databaseCredentialsProvider.notifier);
      final request = notifier.request((mount: 'database', role: 'slow'));
      notifier.clear();
      pending.complete(_creds('database', 'slow'));
      await request;

      expect(container.read(databaseCredentialsProvider).value, isNull);
    });
  });

  group('detection', () {
    test('a token that may not read the role yields no detection', () async {
      await start(base);
      when(
        () => client.describeDatabaseRole('database', 'readonly'),
      ).thenThrow(const PermissionDeniedException('Permission denied.'));
      expect(
        await container.read(
          detectedDatabaseProvider((
            mount: 'database',
            role: 'readonly',
          )).future,
        ),
        isNull,
      );
    });
  });

  group('resolveDbTarget', () {
    const settings = AppSettings(
      databaseClient: 'psql',
      databaseHost: 'pg.default',
      databasePort: 5432,
      databaseName: 'app',
    );

    test('without anything else the profile defaults apply', () {
      final t = resolveDbTarget(settings, 'database', null);
      expect(
        (t.client, t.host, t.port, t.database),
        ('psql', 'pg.default', 5432, 'app'),
      );
    });

    test('a detected engine does not inherit defaults of another engine', () {
      final t = resolveDbTarget(
        settings,
        'cass001/cass001',
        const DetectedDatabase(connection: 'cass001', client: DbClient.cqlsh),
      );
      // A PostgreSQL host is of no use to cqlsh.
      expect((t.client, t.host, t.port, t.database), ('cqlsh', '', 9042, ''));
    });

    test('an unknown stored engine falls back to a real one', () {
      final t = resolveDbTarget(
        settings.copyWith(
          databaseTargets: const {'m': SavedDbTarget(client: 'oracle')},
        ),
        'm',
        null,
      );
      expect(DbClient.values.byName(t.client), DbClient.psql);
    });

    test('what the user saved wins over the detected address', () {
      final t = resolveDbTarget(
        settings.copyWith(
          databaseTargets: const {
            'database/postgres': SavedDbTarget(host: '127.0.0.1', port: 5432),
          },
        ),
        'database/postgres',
        const DetectedDatabase(
          connection: 'postgres',
          client: DbClient.psql,
          host: 'postgres', // Docker name: only the server can resolve it.
          port: 5432,
        ),
      );
      expect(t.host, '127.0.0.1');
    });

    test('the detected engine wins over a saved one', () {
      final t = resolveDbTarget(
        settings.copyWith(
          databaseTargets: const {'m/c': SavedDbTarget(client: 'psql')},
        ),
        'm/c',
        const DetectedDatabase(connection: 'c', client: DbClient.mysql),
      );
      expect(t.client, 'mysql');
    });
  });

  test('saved targets travel with the server profile', () async {
    await start(base);
    const targets = {'cass001': SavedDbTarget(client: 'cqlsh', host: 'c1')};
    final profile = base
        .copyWith(databaseTargets: targets)
        .toProfile(id: 'p1', name: 'prod');
    expect(profile.databaseTargets, targets);
    expect(const AppSettings().withProfile(profile).databaseTargets, targets);
    // Same path as the keystore: encode, then decode.
    final stored = jsonEncode(base.copyWith(databaseTargets: targets).toJson());
    expect(
      AppSettings.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      ).databaseTargets,
      targets,
    );
  });
}
