import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/models/lease_info.dart';

part 'tracked_lease.freezed.dart';

enum LeaseStatus { active, expiringSoon, expired }

/// A lease issued during this session. Holds no secret material.
@freezed
abstract class TrackedLease with _$TrackedLease {
  const TrackedLease._();

  const factory TrackedLease({
    required String leaseId,
    required String source,
    required DateTime issuedAt,
    required Duration duration,
    required bool renewable,
  }) = _TrackedLease;

  factory TrackedLease.from(LeaseInfo lease, String source, DateTime now) =>
      TrackedLease(
        leaseId: lease.leaseId,
        source: source,
        issuedAt: now,
        duration: lease.leaseDuration,
        renewable: lease.renewable,
      );

  DateTime get expiresAt => issuedAt.add(duration);

  Duration remaining(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Share of the lease still left, from 1.0 (new) to 0.0 (expired).
  double fractionRemaining(DateTime now) => duration.inMilliseconds == 0
      ? 0
      : (remaining(now).inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  /// Expiring soon = under 25% of the lease or 5 minutes, whichever is less.
  LeaseStatus status(DateTime now) {
    final left = remaining(now);
    if (left == Duration.zero) return LeaseStatus.expired;
    final threshold = Duration(
      seconds: math.min(300, (duration.inSeconds * 0.25).ceil()),
    );
    return left <= threshold ? LeaseStatus.expiringSoon : LeaseStatus.active;
  }
}
