import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/app/providers/core_providers.dart';
import 'package:transikey/core/api/vault_api_client.dart';
import 'package:transikey/core/errors/vault_exception.dart';
import 'package:transikey/core/models/auth_response.dart';
import 'package:transikey/core/security/secret_store.dart';
import 'package:transikey/features/auth/presentation/auth_provider.dart';
import 'package:transikey/features/auth/presentation/session_provider.dart';
import 'package:transikey/features/database/presentation/database_provider.dart';
import 'package:transikey/features/settings/domain/app_settings.dart';
import 'package:transikey/features/settings/presentation/settings_provider.dart';
import 'package:transikey/features/ssh/presentation/ssh_provider.dart';

class _MockClient extends Mock implements VaultApiClient {}

const _auth = AuthResponse(
  clientToken: 'hvs.test-token-value',
  accessor: 'acc',
  policies: ['default', 'transikey'],
  leaseDuration: Duration(minutes: 30),
  renewable: true,
  displayName: 'demo',
);

/// Answers like the server: a request without a token is a 403.
void _answerByToken(
  ProviderContainer container,
  Future<List<String>> Function() call,
) {
  when(call).thenAnswer((_) async {
    if (!container.read(tokenHolderProvider).hasToken) {
      throw const PermissionDeniedException('Permission denied.');
    }
    return ['otp', 'sign'];
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockClient client;
  late ProviderContainer container;

  setUp(() async {
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
    await container
        .read(settingsProvider.notifier)
        .save(
          const AppSettings(
            vaultAddr: 'http://127.0.0.1:8200',
            inactivityTimeoutSeconds: 0,
          ),
        );
    container.read(vaultSessionProvider);
    await Future<void>.delayed(Duration.zero);
    when(
      () => client.loginWithUserpass('demo', 'pw'),
    ).thenAnswer((_) async => _auth);
    _answerByToken(container, client.listSshRoles);
    when(client.listSecretMounts).thenAnswer((_) async => const {});
    _answerByToken(container, () => client.listDatabaseRoles('database'));
  });

  // Database roles come grouped by mount: flattened here so both engines
  // share the same expectations.
  final databaseRoleNames = FutureProvider<List<String>>(
    (ref) async => [
      for (final g in await ref.watch(databaseRolesProvider.future)) ...g.roles,
    ],
  );

  for (final (name, provider) in [
    ('SSH', sshRolesProvider),
    ('database', databaseRoleNames),
  ]) {
    test('$name roles are not requested without a session', () async {
      // A screen can be on display (and listening) before sign-in.
      container.listen(provider, (_, __) {});

      expect(await container.read(provider.future), isEmpty);
      verifyNever(client.listSshRoles);
      verifyNever(() => client.listDatabaseRoles(any()));
    });

    test('$name roles load once the session starts', () async {
      container.listen(provider, (_, __) {});
      await container.read(provider.future);

      await container
          .read(vaultAuthProvider.notifier)
          .loginWithUserpass('demo', 'pw');

      expect(await container.read(provider.future), ['otp', 'sign']);
    });

    test('$name roles reload after the session is unlocked', () async {
      container.listen(provider, (_, __) {});
      final auth = container.read(vaultAuthProvider.notifier);
      await auth.loginWithUserpass('demo', 'pw');
      await container.read(provider.future);

      // The screen stays built under the lock overlay and keeps listening.
      container.read(vaultSessionProvider.notifier).lock();
      expect(await container.read(provider.future), isEmpty);
      await auth.loginWithUserpass('demo', 'pw');

      expect(await container.read(provider.future), ['otp', 'sign']);
    });
  }
}
