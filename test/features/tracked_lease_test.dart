import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/features/leases/domain/tracked_lease.dart';

void main() {
  final issued = DateTime(2026, 1, 1, 12);
  TrackedLease lease(Duration d) => TrackedLease(
    leaseId: 'database/creds/ro/abc',
    source: 'database/ro',
    issuedAt: issued,
    duration: d,
    renewable: true,
  );

  test('a fresh lease is active', () {
    expect(lease(const Duration(hours: 1)).status(issued), LeaseStatus.active);
  });

  test('a long lease is expiring soon in its last five minutes', () {
    final l = lease(const Duration(hours: 1));
    expect(
      l.status(issued.add(const Duration(minutes: 54))),
      LeaseStatus.active,
    );
    expect(
      l.status(issued.add(const Duration(minutes: 55))),
      LeaseStatus.expiringSoon,
    );
  });

  test('a short lease is expiring soon in its last quarter', () {
    final l = lease(const Duration(seconds: 60));
    expect(
      l.status(issued.add(const Duration(seconds: 44))),
      LeaseStatus.active,
    );
    expect(
      l.status(issued.add(const Duration(seconds: 45))),
      LeaseStatus.expiringSoon,
    );
  });

  test('a lease past its end is expired with zero remaining', () {
    final l = lease(const Duration(seconds: 60));
    final later = issued.add(const Duration(minutes: 5));
    expect(l.status(later), LeaseStatus.expired);
    expect(l.remaining(later), Duration.zero);
    expect(l.fractionRemaining(later), 0);
  });

  test('a zero-length lease is expired immediately', () {
    expect(lease(Duration.zero).status(issued), LeaseStatus.expired);
  });
}
