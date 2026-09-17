import 'dart:convert';

import '../../../core/security/secret_store.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

class SecureSettingsRepository implements SettingsRepository {
  SecureSettingsRepository(this._store, this._log);

  static const _key = 'transikey.settings';

  final SecretStore _store;
  final AppLogger _log;

  @override
  Future<AppSettings> load() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null || raw.isEmpty) return const AppSettings();
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      _log.error('settings.load.failed', error: e, stackTrace: st);
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) =>
      _store.write(_key, jsonEncode(settings.toJson()));
}
