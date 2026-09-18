import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/app/providers/core_providers.dart';
import 'package:transikey/core/security/secret_store.dart';
import 'package:transikey/features/settings/domain/app_settings.dart';
import 'package:transikey/features/settings/presentation/settings_provider.dart';

void main() {
  late ProviderContainer container;
  late InMemorySecretStore store;

  SettingsNotifier notifier() => container.read(settingsProvider.notifier);
  AppSettings settings() => container.read(settingsProvider).value!;

  setUp(() async {
    store = InMemorySecretStore();
    container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [secretStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);
    await notifier().save(
      const AppSettings(
        vaultAddr: 'https://bao.prod.example:8200',
        namespace: 'team-a',
        sshMount: 'ssh-prod',
        databaseHost: 'pg.prod.example',
        lastAuthMethod: 'ldap',
        lastUsername: 'sergio',
      ),
    );
  });

  test(
    'saving a profile captures the server fields and activates it',
    () async {
      final profile = await notifier().saveAsProfile(
        ' prod ',
        color: 0xFFCF222E,
      );

      expect(profile.name, 'prod');
      expect(profile.vaultAddr, 'https://bao.prod.example:8200');
      expect(profile.sshMount, 'ssh-prod');
      expect(profile.lastUsername, 'sergio');
      expect(settings().activeProfileId, profile.id);
      expect(settings().activeProfile!.color, 0xFFCF222E);
    },
  );

  test('edits while a profile is active are written back to it', () async {
    final profile = await notifier().saveAsProfile('prod');

    await notifier().change(
      (s) => s.copyWith(databaseHost: 'pg2.prod.example'),
    );

    expect(
      settings().profiles.singleWhere((p) => p.id == profile.id).databaseHost,
      'pg2.prod.example',
    );
  });

  test(
    'switching profiles swaps every server field and leaves globals alone',
    () async {
      final prod = await notifier().saveAsProfile('prod');
      await notifier().detachProfile();
      await notifier().change(
        (s) => s.copyWith(
          vaultAddr: 'http://127.0.0.1:8200',
          namespace: '',
          sshMount: 'ssh',
          databaseHost: '127.0.0.1',
          lastAuthMethod: 'token',
          lastUsername: '',
          clipboardClearSeconds: 10,
        ),
      );
      final dev = await notifier().saveAsProfile('dev');

      await notifier().applyProfile(prod.id);

      expect(settings().activeProfileId, prod.id);
      expect(settings().vaultAddr, 'https://bao.prod.example:8200');
      expect(settings().namespace, 'team-a');
      expect(settings().sshMount, 'ssh-prod');
      expect(settings().lastUsername, 'sergio');
      expect(settings().clipboardClearSeconds, 10, reason: 'global setting');
      // dev kept its own values
      expect(
        settings().profiles.singleWhere((p) => p.id == dev.id).vaultAddr,
        'http://127.0.0.1:8200',
      );
    },
  );

  test('a detached edit never touches the saved profile', () async {
    final prod = await notifier().saveAsProfile('prod');

    await notifier().detachProfile();
    await notifier().change((s) => s.copyWith(vaultAddr: 'https://other:8200'));

    expect(settings().activeProfileId, isNull);
    expect(
      settings().profiles.singleWhere((p) => p.id == prod.id).vaultAddr,
      'https://bao.prod.example:8200',
    );
  });

  test(
    'deleting the active profile detaches but keeps the live fields',
    () async {
      final prod = await notifier().saveAsProfile('prod');

      await notifier().deleteProfile(prod.id);

      expect(settings().profiles, isEmpty);
      expect(settings().activeProfileId, isNull);
      expect(settings().vaultAddr, 'https://bao.prod.example:8200');
    },
  );

  test('renaming with an empty name keeps the old name', () async {
    final prod = await notifier().saveAsProfile('prod');

    await notifier().updateProfile(prod.id, name: '  ', color: 0xFF1F6FEB);

    expect(settings().profiles.single.name, 'prod');
    expect(settings().profiles.single.color, 0xFF1F6FEB);
  });

  test('applying an unknown profile id changes nothing', () async {
    final before = settings();
    await notifier().applyProfile('nope');
    expect(settings(), before);
  });

  test('profiles survive a restart and hold no secrets', () async {
    await notifier().saveAsProfile('prod');
    final raw = await store.read('transikey.settings');

    final restarted = ProviderContainer(
      overrides: [secretStoreProvider.overrideWithValue(store)],
    );
    addTearDown(restarted.dispose);
    final loaded = await restarted.read(settingsProvider.future);

    expect(loaded.profiles.single.name, 'prod');
    expect(loaded.activeProfile, isNotNull);
    expect(raw, isNot(contains('password')));
    expect(raw, isNot(contains('token":')));
  });
}
