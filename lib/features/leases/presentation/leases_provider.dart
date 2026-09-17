import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/errors/vault_exception.dart';
import '../../../core/models/lease_info.dart';
import '../data/vault_lease_repository.dart';
import '../domain/lease_repository.dart';
import '../domain/tracked_lease.dart';

final leaseRepositoryProvider = Provider<LeaseRepository>(
  (ref) => VaultLeaseRepository(ref.watch(apiClientProvider)),
);

/// Emits the current time once per second; drives every countdown.
final clockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final leasesProvider = NotifierProvider<LeasesNotifier, List<TrackedLease>>(
  LeasesNotifier.new,
);

class LeasesNotifier extends Notifier<List<TrackedLease>> {
  @override
  List<TrackedLease> build() => const [];

  void track(LeaseInfo lease, String source) {
    if (lease.leaseId.isEmpty) return;
    state = [
      TrackedLease.from(lease, source, DateTime.now()),
      ...state.where((l) => l.leaseId != lease.leaseId),
    ];
  }

  Future<void> renew(String leaseId) async {
    try {
      final renewed = await ref.read(leaseRepositoryProvider).renew(leaseId);
      state = [
        for (final lease in state)
          if (lease.leaseId == leaseId)
            lease.copyWith(
              issuedAt: DateTime.now(),
              duration: renewed.leaseDuration,
              renewable: renewed.renewable,
            )
          else
            lease,
      ];
    } on LeaseExpiredException {
      _markExpired(leaseId);
      rethrow;
    }
  }

  Future<void> revoke(String leaseId) async {
    await ref.read(leaseRepositoryProvider).revoke(leaseId);
    remove(leaseId);
  }

  void remove(String leaseId) =>
      state = state.where((l) => l.leaseId != leaseId).toList();

  void clearExpired() {
    final now = DateTime.now();
    state = state.where((l) => l.status(now) != LeaseStatus.expired).toList();
  }

  void _markExpired(String leaseId) => state = [
    for (final lease in state)
      lease.leaseId == leaseId
          ? lease.copyWith(duration: Duration.zero)
          : lease,
  ];
}
