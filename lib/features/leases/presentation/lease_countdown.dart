import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/async_value_view.dart';
import '../domain/tracked_lease.dart';
import 'leases_provider.dart';

Color leaseStatusColor(LeaseStatus status) => switch (status) {
  LeaseStatus.active => StatusColors.active,
  LeaseStatus.expiringSoon => StatusColors.expiringSoon,
  LeaseStatus.expired => StatusColors.expired,
};

String leaseStatusLabel(LeaseStatus status) => switch (status) {
  LeaseStatus.active => 'Active',
  LeaseStatus.expiringSoon => 'Expiring soon',
  LeaseStatus.expired => 'Expired',
};

/// Live countdown, progress bar and renew / revoke actions for one lease.
/// Rebuilds every second through [clockProvider].
class LeaseCountdown extends ConsumerWidget {
  const LeaseCountdown({super.key, required this.leaseId});

  final String leaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lease = ref.watch(
      leasesProvider.select(
        (all) => all.where((l) => l.leaseId == leaseId).firstOrNull,
      ),
    );
    if (lease == null) {
      return const Text('Lease revoked or no longer tracked.');
    }
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final status = lease.status(now);
    final color = leaseStatusColor(status);
    final notifier = ref.read(leasesProvider.notifier);

    Future<void> run(Future<void> Function() action, String done) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
        messenger.showSnackBar(SnackBar(content: Text(done)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 8),
            Text(leaseStatusLabel(status)),
            const SizedBox(width: 16),
            Text(
              formatDuration(lease.remaining(now)),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            if (lease.renewable && status != LeaseStatus.expired)
              TextButton.icon(
                onPressed: () =>
                    run(() => notifier.renew(leaseId), 'Lease renewed'),
                icon: const Icon(Icons.autorenew),
                label: const Text('Renew'),
              ),
            if (status != LeaseStatus.expired)
              TextButton.icon(
                onPressed: () =>
                    run(() => notifier.revoke(leaseId), 'Lease revoked'),
                icon: const Icon(Icons.block),
                label: const Text('Revoke'),
              )
            else
              TextButton.icon(
                onPressed: () => notifier.remove(leaseId),
                icon: const Icon(Icons.clear),
                label: const Text('Dismiss'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: lease.fractionRemaining(now),
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
