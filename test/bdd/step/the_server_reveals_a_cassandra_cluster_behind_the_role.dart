import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/core/utils/db_connect_command.dart';
import 'package:transikey/core/utils/db_target_detection.dart';

import 'database_world.dart';

/// Usage: the server reveals a Cassandra cluster behind the role {'readonly'}
Future<void> theServerRevealsACassandraClusterBehindTheRole(
  WidgetTester tester,
  String role,
) async {
  when(() => DatabaseWorld.server.describeDatabaseRole(any(), role)).thenAnswer(
    (_) async => const DetectedDatabase(
      connection: 'cass001',
      client: DbClient.cqlsh,
      host: 'c1.internal',
      port: 9042,
    ),
  );
}
