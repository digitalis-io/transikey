import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/core/errors/vault_exception.dart';
import 'package:transikey/core/models/database_credentials.dart';
import 'package:transikey/core/models/lease_info.dart';

import 'database_world.dart';

/// Usage: a server that offers database roles
///
/// The least-privilege case: one mount, and a token that may not read what
/// is behind a role.
Future<void> aServerThatOffersDatabaseRoles(WidgetTester tester) async {
  final server = DatabaseWorld.server = FakeDatabaseServer();
  DatabaseWorld.mounts = {'database': 'database', 'ssh': 'ssh'};
  when(server.listSecretMounts).thenAnswer((_) async => DatabaseWorld.mounts);
  when(
    () => server.listDatabaseRoles('database'),
  ).thenAnswer((_) async => const ['readonly', 'short-lived']);
  when(
    () => server.describeDatabaseRole(any(), any()),
  ).thenThrow(const PermissionDeniedException('Permission denied.'));
  when(() => server.getDatabaseCredentials(any(), any())).thenAnswer((
    call,
  ) async {
    final [mount as String, role as String] = call.positionalArguments;
    return DatabaseCredentials(
      mount: mount,
      role: role,
      username: 'v-token-$role',
      password: 'generated-password',
      lease: LeaseInfo(
        leaseId: '$mount/creds/$role/1',
        leaseDuration: const Duration(minutes: 10),
        renewable: true,
      ),
    );
  });
}
