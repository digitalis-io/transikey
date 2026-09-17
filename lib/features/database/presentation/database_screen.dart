import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/clipboard_actions.dart';
import '../../../core/models/database_credentials.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/resizable_split.dart';
import '../../../core/widgets/role_picker.dart';
import '../../../core/widgets/secret_field.dart';
import '../../leases/presentation/lease_countdown.dart';
import 'database_provider.dart';

class DatabaseScreen extends ConsumerStatefulWidget {
  const DatabaseScreen({super.key});

  @override
  ConsumerState<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends ConsumerState<DatabaseScreen> {
  String? _role;

  @override
  Widget build(BuildContext context) {
    final credentials = ref.watch(databaseCredentialsProvider);
    return FeaturePage(
      title: 'Database Credentials',
      scrollable: false,
      child: ResizableSplit(
        left: RolePicker(
          roles: ref.watch(databaseRolesProvider),
          selected: _role,
          onSelected: (r) => setState(() => _role = r),
          onRefresh: () => ref.invalidate(databaseRolesProvider),
        ),
        right: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.icon(
                onPressed: _role == null || credentials.isLoading
                    ? null
                    : () => ref
                          .read(databaseCredentialsProvider.notifier)
                          .request(_role!),
                icon: const Icon(Icons.vpn_key),
                label: Text(
                  _role == null
                      ? 'Select a role'
                      : 'Request credentials for $_role',
                ),
              ),
              const SizedBox(height: 16),
              AsyncValueView<DatabaseCredentials?>(
                value: credentials,
                empty: 'Request credentials to see them here.',
                data: (c) => _CredentialsCard(c!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialsCard extends ConsumerWidget {
  const _CredentialsCard(this.credentials);

  final DatabaseCredentials credentials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void copy(String v) => copySecret(context, ref, v);
    final lease = credentials.lease;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SecretField(
              label: 'Username',
              value: credentials.username,
              onCopy: copy,
            ),
            SecretField(
              label: 'Password',
              value: credentials.password,
              onCopy: copy,
            ),
            SecretField(
              label: 'Lease ID',
              value: lease.leaseId,
              sensitive: false,
              onCopy: copy,
            ),
            SecretField(
              label: 'Lease duration',
              value: '${lease.leaseDuration.inSeconds}s',
              sensitive: false,
              onCopy: copy,
            ),
            SecretField(
              label: 'Renewable',
              value: lease.renewable ? 'Yes' : 'No',
              sensitive: false,
              onCopy: copy,
            ),
            const SizedBox(height: 8),
            LeaseCountdown(leaseId: lease.leaseId),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: ref.read(databaseCredentialsProvider.notifier).clear,
              icon: const Icon(Icons.visibility_off),
              label: const Text('Clear from screen'),
            ),
          ],
        ),
      ),
    );
  }
}
