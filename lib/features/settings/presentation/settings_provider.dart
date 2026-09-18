import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/models/health_status.dart';
import '../data/secure_settings_repository.dart';
import '../data/vault_connection_repository.dart';
import '../domain/app_settings.dart';
import '../domain/server_profile.dart';
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

  /// Every save keeps the active profile in step with the live fields.
  Future<void> save(AppSettings settings) async {
    final synced = settings.syncActiveProfile();
    await ref.read(settingsRepositoryProvider).save(synced);
    state = AsyncData(synced);
  }

  AppSettings get _current => state.value ?? const AppSettings();

  /// Remembers the current server under [name] and makes it active.
  Future<ServerProfile> saveAsProfile(String name, {int color = 0}) async {
    final profile = _current.toProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      color: color,
    );
    await save(
      _current.copyWith(
        profiles: [..._current.profiles, profile],
        activeProfileId: profile.id,
      ),
    );
    return profile;
  }

  /// Loads [id] into the live fields. Callers end the session first: see
  /// `switchServerProfile`.
  Future<void> applyProfile(String id) async {
    final profile = _current.profiles.where((p) => p.id == id).firstOrNull;
    if (profile != null) await save(_current.withProfile(profile));
  }

  /// Keeps the live fields but stops writing them to any profile.
  Future<void> detachProfile() =>
      save(_current.copyWith(activeProfileId: null));

  Future<void> updateProfile(String id, {String? name, int? color}) => save(
    _current.copyWith(
      profiles: [
        for (final p in _current.profiles)
          p.id == id
              ? p.copyWith(
                  name: name?.trim().isNotEmpty == true ? name!.trim() : p.name,
                  color: color ?? p.color,
                )
              : p,
      ],
    ),
  );

  Future<void> deleteProfile(String id) => save(
    _current.copyWith(
      profiles: _current.profiles.where((p) => p.id != id).toList(),
      activeProfileId: _current.activeProfileId == id
          ? null
          : _current.activeProfileId,
    ),
  );

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
