import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'sharing_world.dart';

/// Usage: no secret has been requested
Future<void> noSecretHasBeenRequested(WidgetTester tester) async {
  verifyNever(() => SharingWorld.server.unwrapSecret(any()));
}
