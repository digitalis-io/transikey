import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/database_credentials.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/resizable_split.dart';
import '../../../core/widgets/role_picker.dart';
import 'database_credentials_card.dart';
import 'database_provider.dart';

class DatabaseScreen extends ConsumerStatefulWidget {
  const DatabaseScreen({super.key});

  @override
  ConsumerState<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends ConsumerState<DatabaseScreen> {
  DatabaseRoleRef? _selected;

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(databaseRolesProvider);
    final credentials = ref.watch(databaseCredentialsProvider);
    final selected = _selected;
    final severalMounts = (groups.value?.length ?? 0) > 1;
    final label = selected == null
        ? null
        : severalMounts
        ? '${selected.mount}/${selected.role}'
        : selected.role;

    return FeaturePage(
      title: 'Database Credentials',
      scrollable: false,
      child: ResizableSplit(
        left: RolePicker(
          groups: groups,
          selected: selected == null ? null : (selected.mount, selected.role),
          onSelected: (mount, role) {
            final picked = (mount: mount, role: role);
            if (picked == selected) return;
            // Credentials of the previous role must not linger on screen.
            ref.read(databaseCredentialsProvider.notifier).clear();
            setState(() => _selected = picked);
          },
          onRefresh: () {
            ref.invalidate(databaseMountsProvider);
            ref.invalidate(databaseRolesProvider);
            // Policy may have changed: ask again what is behind a role.
            ref.invalidate(detectedDatabaseProvider);
          },
        ),
        right: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.icon(
                onPressed: selected == null || credentials.isLoading
                    ? null
                    : () => ref
                          .read(databaseCredentialsProvider.notifier)
                          .request(selected),
                icon: const Icon(Icons.vpn_key),
                label: Text(
                  label == null
                      ? 'Request credentials'
                      : 'Request credentials for $label',
                ),
              ),
              if (selected == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Pick a role in the list on the left first.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              AsyncValueView<DatabaseCredentials?>(
                value: credentials,
                empty: 'Request credentials to see them here.',
                data: (c) => DatabaseCredentialsCard(c!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
