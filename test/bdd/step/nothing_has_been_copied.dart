import 'package:flutter_test/flutter_test.dart';

import 'kubernetes_world.dart';

/// Usage: nothing has been copied
Future<void> nothingHasBeenCopied(WidgetTester tester) async {
  expect(KubernetesWorld.clipboard.copies, isEmpty);
}
