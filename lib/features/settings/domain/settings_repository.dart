import '../../../core/models/health_status.dart';
import 'app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

abstract class ConnectionRepository {
  /// Fetches `sys/health` from the configured server.
  Future<HealthStatus> health();

  /// Probes [settings] without persisting them.
  Future<HealthStatus> test(AppSettings settings);
}
