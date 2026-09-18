import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/features/auth/presentation/auth_screen.dart';
import 'package:transikey/features/settings/domain/server_profile.dart';
import 'package:transikey/features/settings/presentation/settings_provider.dart';

/// Usage: the servers {'prod'} and {'dev'} are remembered
Future<void> theServersAndAreRemembered(
  WidgetTester tester,
  String first,
  String second,
) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AuthScreen)),
  );
  ServerProfile profile(String name) => ServerProfile(
    id: name,
    name: name,
    vaultAddr: 'https://bao.$name.example:8200',
    lastAuthMethod: 'ldap',
    lastUsername: 'sergio',
  );
  await container
      .read(settingsProvider.notifier)
      .change((s) => s.copyWith(profiles: [profile(first), profile(second)]));
  await tester.pumpAndSettle();
}
