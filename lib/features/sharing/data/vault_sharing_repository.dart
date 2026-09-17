import '../../../core/api/vault_api_client.dart';
import '../../../core/models/wrapped_secret.dart';
import '../domain/sharing_repository.dart';

class VaultSharingRepository implements SharingRepository {
  VaultSharingRepository(this._client, this._clientFor);

  final VaultApiClient _client;

  /// Builds a client for another server, reusing the saved TLS settings.
  final VaultApiClient Function(String address, String namespace) _clientFor;

  @override
  Future<WrappedSecret> wrap(Map<String, dynamic> payload, Duration ttl) =>
      _client.wrapSecret(payload, ttl);

  @override
  Future<UnwrappedSecret> unwrap(
    String wrappingToken, {
    String? address,
    String? namespace,
  }) {
    final other = address?.trim() ?? '';
    final client = other.isEmpty
        ? _client
        : _clientFor(other, namespace?.trim() ?? '');
    return client.unwrapSecret(wrappingToken);
  }

  @override
  Future<void> cubbyholeStore(String path, Map<String, dynamic> data) =>
      _client.cubbyholeWrite(path, data);

  @override
  Future<Map<String, dynamic>> cubbyholeRetrieve(String path) =>
      _client.cubbyholeRead(path);

  @override
  Future<void> cubbyholeDelete(String path) => _client.cubbyholeDelete(path);

  @override
  Future<List<String>> cubbyholeList() => _client.cubbyholeList();
}
