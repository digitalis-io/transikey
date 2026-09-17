// Live tests against a real OpenBao / Vault server.
//
//   docker compose -f dev/docker-compose.yml up -d
//   BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=root flutter test test/integration
//
// Skipped when BAO_ADDR or BAO_TOKEN is not set. Expects the mounts, roles
// and user created by dev/init.sh.
@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/api/dio_factory.dart';
import 'package:transikey/core/api/dio_vault_api_client.dart';
import 'package:transikey/core/api/vault_connection_config.dart';
import 'package:transikey/core/errors/vault_exception.dart';
import 'package:transikey/core/utils/app_logger.dart';

const _publicKey =
    'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKHEoTlxhQjqs1uTvVJHAQVwXrWUEgHJ0hZvOaRKWTaK transikey-test';

void main() {
  final env = Platform.environment;
  final address = (env['BAO_ADDR'] ?? env['VAULT_ADDR'] ?? '').replaceFirst(
    '0.0.0.0',
    '127.0.0.1',
  );
  final rootToken = env['BAO_TOKEN'] ?? env['VAULT_TOKEN'] ?? '';
  final user = env['DEV_USER'] ?? 'demo';
  final password = env['DEV_USER_PASSWORD'] ?? 'transikey-dev';
  final skip = address.isEmpty || rootToken.isEmpty
      ? 'BAO_ADDR / BAO_TOKEN not set'
      : null;

  late TokenHolder holder;
  late DioVaultApiClient client;

  setUp(() {
    holder = TokenHolder();
    final config = VaultConnectionConfig(address: address);
    client = DioVaultApiClient(
      dio: buildVaultDio(
        config: config,
        tokenHolder: holder,
        logger: AppLogger(),
      ),
      config: config,
    );
  });

  Future<void> signInAsUser() async =>
      holder.set((await client.loginWithUserpass(user, password)).clientToken);

  group('connection', () {
    test('health reports an initialised, unsealed server', () async {
      final health = await client.health();
      expect(health.initialized, isTrue);
      expect(health.sealed, isFalse);
      expect(health.version, isNotEmpty);
    });

    test('an unreachable server is a NetworkException', () async {
      const config = VaultConnectionConfig(
        address: 'http://127.0.0.1:1',
        connectTimeout: Duration(seconds: 2),
        maxRetries: 0,
      );
      final dead = DioVaultApiClient(
        dio: buildVaultDio(
          config: config,
          tokenHolder: TokenHolder(),
          logger: AppLogger(),
        ),
        config: config,
      );
      await expectLater(dead.health(), throwsA(isA<NetworkException>()));
    });
  }, skip: skip);

  group('authentication', () {
    test('token login returns the token policies', () async {
      final auth = await client.loginWithToken(rootToken);
      expect(auth.policies, contains('root'));
    });

    test('an invalid token is an AuthenticationException', () async {
      await expectLater(
        client.loginWithToken('not-a-real-token'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test(
      'userpass login yields a renewable token with the transikey policy',
      () async {
        final auth = await client.loginWithUserpass(user, password);
        expect(auth.clientToken, isNotEmpty);
        expect(auth.policies, contains('transikey'));
        expect(auth.displayName, user);
        holder.set(auth.clientToken);
        expect(
          (await client.renewSelf()).leaseDuration,
          greaterThan(Duration.zero),
        );
      },
    );

    test('a wrong password is an AuthenticationException', () async {
      await expectLater(
        client.loginWithUserpass(user, 'wrong-password'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('ldap login yields a token with the transikey policy', () async {
      final auth = await client.loginWithLdap(
        env['DEV_LDAP_USER'] ?? 'ldapdemo',
        env['DEV_LDAP_USER_PASSWORD'] ?? 'transikey-dev',
      );
      expect(auth.clientToken, isNotEmpty);
      expect(auth.policies, contains('transikey'));
    });

    test('a wrong ldap password is an AuthenticationException', () async {
      await expectLater(
        client.loginWithLdap('ldapdemo', 'wrong-password'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('oidc on a server without an OIDC mount fails cleanly', () async {
      await expectLater(
        client.oidcAuthUrl(
          role: '',
          redirectUri: Uri.parse('http://localhost:8250/oidc/callback'),
          clientNonce: 'nonce',
        ),
        throwsA(isA<VaultException>()),
      );
    });

    test('approle login works with a fresh secret id', () async {
      // Role id and secret id are read with the root token through plain Dio.
      holder.set(rootToken);
      final dio = buildVaultDio(
        config: VaultConnectionConfig(address: address),
        tokenHolder: holder,
        logger: AppLogger(),
      );
      final roleId =
          (await dio.get<Map<String, dynamic>>(
                '/v1/auth/approle/role/transikey/role-id',
              )).data!['data']['role_id']
              as String;
      final secretId =
          (await dio.post<Map<String, dynamic>>(
                '/v1/auth/approle/role/transikey/secret-id',
              )).data!['data']['secret_id']
              as String;
      holder.clear();

      final auth = await client.loginWithAppRole(roleId, secretId);
      expect(auth.policies, contains('transikey'));
    });

    test('revoke-self invalidates the token', () async {
      final auth = await client.loginWithUserpass(user, password);
      holder.set(auth.clientToken);
      await client.revokeSelf();
      await expectLater(
        client.loginWithToken(auth.clientToken),
        throwsA(isA<AuthenticationException>()),
      );
    });
  }, skip: skip);

  group('database credentials', () {
    test('roles are listed', () async {
      await signInAsUser();
      expect(
        await client.listDatabaseRoles(),
        containsAll(['readonly', 'short-lived']),
      );
    });

    test('credentials are issued, renewed, then revoked', () async {
      await signInAsUser();
      final creds = await client.getDatabaseCredentials('readonly');
      expect(creds.username, isNotEmpty);
      expect(creds.password, isNotEmpty);
      expect(creds.lease.leaseId, startsWith('database/creds/readonly/'));
      expect(creds.lease.renewable, isTrue);
      expect(creds.toString(), isNot(contains(creds.password)));

      final renewed = await client.renewLease(creds.lease.leaseId);
      expect(renewed.leaseDuration, greaterThan(Duration.zero));

      await client.revokeLease(creds.lease.leaseId);
      await expectLater(
        client.renewLease(creds.lease.leaseId),
        throwsA(isA<LeaseExpiredException>()),
      );
    });

    test('an unknown role is rejected', () async {
      await signInAsUser();
      await expectLater(
        client.getDatabaseCredentials('no-such-role'),
        throwsA(isA<VaultException>()),
      );
    });

    test('an unauthenticated request is denied', () async {
      await expectLater(
        client.getDatabaseCredentials('readonly'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  }, skip: skip);

  group('ssh', () {
    test('an OTP is issued for a target address', () async {
      await signInAsUser();
      final creds = await client.getSshCredentials('otp', ip: '10.0.0.5');
      expect(creds.otp, isNotEmpty);
      expect(creds.username, 'ubuntu');
      expect(creds.ip, '10.0.0.5');
    });

    test('a missing target address fails local validation', () async {
      await expectLater(
        client.getSshCredentials('otp', ip: ' '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a public key is signed into a certificate', () async {
      await signInAsUser();
      final cert = await client.signPublicKey('sign', _publicKey);
      expect(cert.signedKey, startsWith('ssh-ed25519-cert-v01@openssh.com '));
      expect(cert.serialNumber, isNotEmpty);
    });

    test('a malformed public key is a ValidationException', () async {
      await signInAsUser();
      await expectLater(
        client.signPublicKey('sign', 'not a key'),
        throwsA(isA<ValidationException>()),
      );
    });
  }, skip: skip);

  group('secret sharing', () {
    test('a wrapped secret unwraps exactly once, without a session', () async {
      await signInAsUser();
      final wrapped = await client.wrapSecret({
        'secret': 'one-time value',
      }, const Duration(minutes: 5));
      expect(wrapped.token, isNotEmpty);
      expect(wrapped.ttl, const Duration(minutes: 5));

      holder.clear(); // The recipient has no session.
      final unwrapped = await client.unwrapSecret(wrapped.token);
      expect(unwrapped.data, {'secret': 'one-time value'});

      await expectLater(
        client.unwrapSecret(wrapped.token),
        throwsA(isA<VaultException>()),
      );
    });

    test('an empty payload fails local validation', () async {
      await expectLater(
        client.wrapSecret(const {}, const Duration(minutes: 5)),
        throwsA(isA<ValidationException>()),
      );
    });

    test('cubbyhole stores, lists, retrieves and deletes', () async {
      await signInAsUser();
      expect(await client.cubbyholeList(), isEmpty);

      await client.cubbyholeWrite('handover/db', {'password': 'p@ss'});
      expect(await client.cubbyholeList(), contains('handover/'));
      expect(await client.cubbyholeRead('handover/db'), {'password': 'p@ss'});

      await client.cubbyholeDelete('handover/db');
      await expectLater(
        client.cubbyholeRead('handover/db'),
        throwsA(isA<NotFoundException>()),
      );
    });
  }, skip: skip);
}
