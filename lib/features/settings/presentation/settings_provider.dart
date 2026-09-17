import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/models/health_status.dart';
import '../data/secure_settings_repository.dart';
import '../data/vault_connection_repository.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SecureSettingsRepository(
    ref.watch(secretStoreProvider),
    ref.watch(loggerProvider),
  ),
);

final connectionRepositoryProvider = Provider<ConnectionRepository>(
  (ref) => VaultConnectionRepository(
    client: ref.watch(apiClientProvider),
    clientFor: ref.watch(apiClientFactoryProvider),
  ),
);

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> save(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).save(settings);
    state = AsyncData(settings);
  }

  Future<void> change(AppSettings Function(AppSettings) edit) =>
      save(edit(state.value ?? const AppSettings()));
}

/// Live server health. Polls every [_interval] while a server is configured.
/// `AsyncData(null)` is the empty state: no server configured yet.
final vaultConnectionProvider =
    AsyncNotifierProvider<VaultConnectionNotifier, HealthStatus?>(
      VaultConnectionNotifier.new,
    );

class VaultConnectionNotifier extends AsyncNotifier<HealthStatus?> {
  static const _interval = Duration(seconds: 15);

  @override
  Future<HealthStatus?> build() async {
    final configured = ref.watch(
      settingsProvider.select((s) => s.value?.isConfigured ?? false),
    );
    if (!configured) return null;
    final repository = ref.watch(connectionRepositoryProvider);
    final timer = Timer.periodic(_interval, (_) => _poll(repository));
    ref.onDispose(timer.cancel);
    return repository.health();
  }

  Future<void> refresh() => _poll(ref.read(connectionRepositoryProvider));

  Future<void> _poll(ConnectionRepository repository) async {
    final next = await AsyncValue.guard(repository.health);
    if (ref.mounted) state = next;
  }

  /// One-off probe of unsaved settings for the "Test connection" button.
  Future<HealthStatus> test(AppSettings settings) =>
      ref.read(connectionRepositoryProvider).test(settings);
}
