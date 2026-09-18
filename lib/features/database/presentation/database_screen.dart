import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/clipboard_actions.dart';
import '../../../core/models/database_credentials.dart';
import '../../../core/utils/db_connect_command.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/resizable_split.dart';
import '../../../core/widgets/role_picker.dart';
import '../../../core/widgets/secret_field.dart';
import '../../leases/presentation/lease_countdown.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_provider.dart';
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
          onSelected: (r) {
            if (r == _role) return;
            // Credentials of the previous role must not linger on screen.
            ref.read(databaseCredentialsProvider.notifier).clear();
            setState(() => _role = r);
          },
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
                      ? 'Request credentials'
                      : 'Request credentials for $_role',
                ),
              ),
              if (_role == null)
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
            const Divider(height: 24),
            _ConnectSection(credentials: credentials),
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

/// Ready-to-paste client command and URI. Host, port and database name are
/// not part of the Vault response, so they are user settings.
class _ConnectSection extends ConsumerStatefulWidget {
  const _ConnectSection({required this.credentials});

  final DatabaseCredentials credentials;

  @override
  ConsumerState<_ConnectSection> createState() => _ConnectSectionState();
}

class _ConnectSectionState extends ConsumerState<_ConnectSection> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _database;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider).value ?? const AppSettings();
    _host = TextEditingController(text: s.databaseHost);
    _port = TextEditingController(text: '${s.databasePort}');
    _database = TextEditingController(text: s.databaseName);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _database.dispose();
    super.dispose();
  }

  Future<void> _save(AppSettings Function(AppSettings) change) =>
      ref.read(settingsProvider.notifier).change(change);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final client = DbClient.values.firstWhere(
      (c) => c.name == settings.databaseClient,
      orElse: () => DbClient.psql,
    );
    final target = DbTarget(
      client: client,
      host: settings.databaseHost,
      port: settings.databasePort,
      database: settings.databaseName,
    );
    final creds = widget.credentials;
    void copy(String v) => copySecret(context, ref, v);
    Widget field(
      TextEditingController c,
      String label,
      void Function(String) onChanged, {
      double width = 160,
    }) => SizedBox(
      width: width,
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connect', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<DbClient>(
              segments: [
                for (final c in DbClient.values)
                  ButtonSegment(value: c, label: Text(c.label)),
              ],
              selected: {client},
              onSelectionChanged: (s) =>
                  _save((x) => x.copyWith(databaseClient: s.first.name)),
            ),
            field(
              _host,
              'Host',
              (v) => _save((x) => x.copyWith(databaseHost: v)),
            ),
            field(_port, 'Port', (v) {
              final port = int.tryParse(v.trim());
              if (port != null) _save((x) => x.copyWith(databasePort: port));
            }, width: 90),
            field(
              _database,
              'Database',
              (v) => _save((x) => x.copyWith(databaseName: v)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SecretField(
          label: '${client.binary} command',
          value: dbConnectCommand(target, creds.username, creds.password),
          multiline: true,
          onCopy: copy,
        ),
        SecretField(
          label: 'Connection URI',
          value: dbConnectUri(target, creds.username, creds.password),
          multiline: true,
          onCopy: copy,
        ),
      ],
    );
  }
}
