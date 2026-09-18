import '../../../core/models/lease_info.dart';

abstract class LeaseRepository {
  Future<LeaseInfo> renew(String leaseId, {Duration? increment});
  Future<void> revoke(String leaseId);
}
