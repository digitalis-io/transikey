import '../../../core/api/vault_api_client.dart';
import '../../../core/models/database_credentials.dart';
import '../domain/database_repository.dart';

class VaultDatabaseRepository implements DatabaseRepository {
  VaultDatabaseRepository(this._client);

  final VaultApiClient _client;

  @override
  Future<List<String>> listRoles() => _client.listDatabaseRoles();

  @override
  Future<DatabaseCredentials> requestCredentials(String role) =>
      _client.getDatabaseCredentials(role);
}
