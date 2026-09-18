import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'database_world.dart';

/// Usage: the database mount {'cass001'} offers the role {'operator'}
Future<void> theDatabaseMountOffersTheRole(
  WidgetTester tester,
  String mount,
  String role,
) async {
  DatabaseWorld.mounts[mount] = 'database';
  when(
    () => DatabaseWorld.server.listDatabaseRoles(mount),
  ).thenAnswer((_) async => [role]);
}
