import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/core/errors/vault_exception.dart';

import 'database_world.dart';

/// Usage: the database mount {'locked'} refuses to list its roles
Future<void> theDatabaseMountRefusesToListItsRoles(
  WidgetTester tester,
  String mount,
) async {
  DatabaseWorld.mounts[mount] = 'database';
  when(
    () => DatabaseWorld.server.listDatabaseRoles(mount),
  ).thenThrow(const PermissionDeniedException('Permission denied.'));
}
