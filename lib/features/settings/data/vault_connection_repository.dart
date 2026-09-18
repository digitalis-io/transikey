import '../../../core/api/vault_api_client.dart';
import '../../../core/errors/vault_exception.dart';
import '../../../core/models/health_status.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

class VaultConnectionRepository implements ConnectionRepository {
  VaultConnectionRepository({
    required VaultApiClient client,
    required VaultApiClient Function(AppSettings) clientFor,
  }) : _client = client,
       _clientFor = clientFor;

  final VaultApiClient _client;
  final VaultApiClient Function(AppSettings) _clientFor;

  @override
  Future<HealthStatus> health() => _client.health();

  @override
  Future<HealthStatus> test(AppSettings settings) {
    final uri = Uri.tryParse(settings.vaultAddr.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ValidationException(
        'Enter a full URL, for example https://vault.example.com:8200.',
      );
    }
    return _clientFor(settings).health();
  }
}
