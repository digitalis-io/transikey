import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/core/errors/vault_exception.dart';

import 'kubernetes_world.dart';

/// Usage: the server has no Kubernetes engine
///
/// No mount of that type: the app falls back to the `kubernetes` mount
/// from settings, which the server does not know.
Future<void> theServerHasNoKubernetesEngine(WidgetTester tester) async {
  KubernetesWorld.mounts.remove('kubernetes');
  when(
    () => KubernetesWorld.server.listKubernetesRoles('kubernetes'),
  ).thenThrow(
    const NotFoundException('Not found. Check the mount path and role name.'),
  );
}
