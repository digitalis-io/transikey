import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/app/providers/core_providers.dart';
import 'package:transikey/core/api/vault_api_client.dart';
import 'package:transikey/core/errors/vault_exception.dart';
import 'package:transikey/core/models/auth_response.dart';
import 'package:transikey/core/security/secret_store.dart';
import 'package:transikey/features/auth/domain/vault_session.dart';
import 'package:transikey/features/auth/presentation/auth_provider.dart';
import 'package:transikey/features/auth/presentation/session_provider.dart';
import 'package:transikey/features/settings/domain/app_settings.dart';
import 'package:transikey/features/settings/presentation/settings_provider.dart';

class _MockClient extends Mock implements VaultApiClient {}

const _auth = AuthResponse(
  clientToken: 'hvs.test-token-value',
  accessor: 'acc',
  policies: ['default', 'transikey'],
  leaseDuration: Duration(minutes: 30),
  renewable: true,
  displayName: 'demo',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockClient client;
  late InMemorySecretStore store;
  late ProviderContainer container;

  Future<void> setUpContainer({
    String address = 'http://127.0.0.1:8200',
  }) async {
    client = _MockClient();
    store = InMemorySecretStore();
    container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [
        apiClientProvider.overrideWithValue(client),
        secretStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);
    await container
        .read(settingsProvider.notifier)
        .save(AppSettings(vaultAddr: address, inactivityTimeoutSeconds: 0));
    container.read(vaultSessionProvider);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'userpass login authenticates, stores the token, fills TokenHolder',
    () async {
      await setUpContainer();
      when(
        () => client.loginWithUserpass('demo', 'pw'),
      ).thenAnswer((_) async => _auth);

      await container
          .read(vaultAuthProvider.notifier)
          .loginWithUserpass('demo', 'pw');

      final state = container.read(vaultSessionProvider);
      expect(state, isA<SessionAuthenticated>());
      expect(
        (state as SessionAuthenticated).session.method,
        AuthMethod.userpass,
      );
      expect(container.read(tokenHolderProvider).token, _auth.clientToken);
      expect(await store.read('transikey.session.token'), _auth.clientToken);
      expect(container.read(vaultAuthProvider).hasError, isFalse);
    },
  );

  test('rejected credentials surface an error and leave no session', () async {
    await setUpContainer();
    when(
      () => client.loginWithToken(any()),
    ).thenThrow(const AuthenticationException('bad token'));

    await container.read(vaultAuthProvider.notifier).loginWithToken('nope');

    expect(
      container.read(vaultAuthProvider).error,
      isA<AuthenticationException>(),
    );
    expect(container.read(vaultSessionProvider), isA<SessionUnauthenticated>());
    expect(container.read(tokenHolderProvider).hasToken, isFalse);
  });

  test('login without a configured server is a validation error', () async {
    await setUpContainer(address: '');

    await container.read(vaultAuthProvider.notifier).loginWithToken('t');

    expect(container.read(vaultAuthProvider).error, isA<ValidationException>());
    verifyNever(() => client.loginWithToken(any()));
  });

  test(
    'lock drops the token from memory but keeps the keystore copy',
    () async {
      await setUpContainer();
      when(
        () => client.loginWithAppRole('r', 's'),
      ).thenAnswer((_) async => _auth);
      await container
          .read(vaultAuthProvider.notifier)
          .loginWithAppRole('r', 's');

      container.read(vaultSessionProvider.notifier).lock();

      expect(container.read(vaultSessionProvider), isA<SessionLocked>());
      expect(container.read(tokenHolderProvider).hasToken, isFalse);
      expect(await store.read('transikey.session.token'), isNotNull);
    },
  );

  test('logout never revokes a token the user supplied', () async {
    await setUpContainer();
    when(() => client.loginWithToken('t')).thenAnswer((_) async => _auth);
    await container.read(vaultAuthProvider.notifier).loginWithToken('t');

    await container.read(vaultSessionProvider.notifier).logout();

    verifyNever(() => client.revokeSelf());
    expect(container.read(vaultSessionProvider), isA<SessionUnauthenticated>());
    expect(await store.read('transikey.session.token'), isNull);
  });

  test('logout revokes a minted token and wipes memory and keystore', () async {
    await setUpContainer();
    when(
      () => client.loginWithUserpass('demo', 'pw'),
    ).thenAnswer((_) async => _auth);
    when(() => client.revokeSelf()).thenAnswer((_) async {});
    await container
        .read(vaultAuthProvider.notifier)
        .loginWithUserpass('demo', 'pw');

    await container.read(vaultSessionProvider.notifier).logout();

    verify(() => client.revokeSelf()).called(1);
    expect(container.read(vaultSessionProvider), isA<SessionUnauthenticated>());
    expect(container.read(tokenHolderProvider).hasToken, isFalse);
    expect(await store.read('transikey.session.token'), isNull);
  });

  test('logout still clears local state when revocation fails', () async {
    await setUpContainer();
    when(
      () => client.loginWithUserpass('demo', 'pw'),
    ).thenAnswer((_) async => _auth);
    when(
      () => client.revokeSelf(),
    ).thenThrow(const NetworkException('unreachable'));
    await container
        .read(vaultAuthProvider.notifier)
        .loginWithUserpass('demo', 'pw');

    await container.read(vaultSessionProvider.notifier).logout();

    expect(container.read(vaultSessionProvider), isA<SessionUnauthenticated>());
    expect(await store.read('transikey.session.token'), isNull);
  });
}
