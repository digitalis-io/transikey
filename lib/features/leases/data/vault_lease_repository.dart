import '../../../core/api/vault_api_client.dart';
import '../../../core/models/lease_info.dart';
import '../domain/lease_repository.dart';

class VaultLeaseRepository implements LeaseRepository {
  VaultLeaseRepository(this._client);

  final VaultApiClient _client;

  @override
  Future<LeaseInfo> renew(String leaseId, {Duration? increment}) =>
      _client.renewLease(leaseId, increment: increment);

  @override
  Future<void> revoke(String leaseId) => _client.revokeLease(leaseId);
}
