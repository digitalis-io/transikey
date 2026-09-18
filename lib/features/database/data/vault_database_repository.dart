import '../../../core/api/vault_api_client.dart';
import '../../../core/models/database_credentials.dart';
import '../../../core/utils/db_target_detection.dart';
import '../domain/database_repository.dart';

class VaultDatabaseRepository implements DatabaseRepository {
  VaultDatabaseRepository(this._client);

  final VaultApiClient _client;

  @override
  Future<List<String>> discoverMounts() async {
    final mounts = await _client.listSecretMounts();
    return [
      for (final e in mounts.entries)
        if (e.value == 'database') e.key,
    ]..sort();
  }

  @override
  Future<List<String>> listRoles(String mount) =>
      _client.listDatabaseRoles(mount);

  @override
  Future<DatabaseCredentials> requestCredentials(String mount, String role) =>
      _client.getDatabaseCredentials(mount, role);

  @override
  Future<DetectedDatabase> describeRole(String mount, String role) =>
      _client.describeDatabaseRole(mount, role);
}
