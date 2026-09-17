import 'package:freezed_annotation/freezed_annotation.dart';

part 'lease_info.freezed.dart';

/// Lease metadata returned by credential requests and `sys/leases/renew`.
@freezed
abstract class LeaseInfo with _$LeaseInfo {
  const factory LeaseInfo({
    required String leaseId,
    required Duration leaseDuration,
    required bool renewable,
  }) = _LeaseInfo;
}
