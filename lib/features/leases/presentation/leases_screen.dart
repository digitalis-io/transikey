import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_view.dart';
import 'lease_countdown.dart';
import 'leases_provider.dart';

class LeasesScreen extends ConsumerWidget {
  const LeasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leases = ref.watch(leasesProvider);
    return FeaturePage(
      title: 'Lease Management',
      actions: [
        TextButton.icon(
          onPressed: ref.read(leasesProvider.notifier).clearExpired,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('Clear expired'),
        ),
      ],
      child: leases.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No leases yet. Leases issued in this session appear here.',
              ),
            )
          : Column(
              spacing: 12,
              children: [
                for (final lease in leases)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lease.source,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          SelectableText(
                            lease.leaseId,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          LeaseCountdown(leaseId: lease.leaseId),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
