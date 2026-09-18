import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/clipboard_actions.dart';
import '../../../core/models/database_credentials.dart';
import '../../../core/utils/db_connect_command.dart';
import '../../../core/utils/db_target_detection.dart';
import '../../../core/widgets/secret_field.dart';
import '../../leases/presentation/lease_countdown.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/domain/server_profile.dart';
import '../../settings/presentation/settings_provider.dart';
import 'database_provider.dart';

/// Issued credentials, titled `mount/role`.
class DatabaseCredentialsCard extends ConsumerWidget {
  const DatabaseCredentialsCard(this.credentials, {super.key});

  final DatabaseCredentials credentials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void copy(String v) => copySecret(context, ref, v);
    final c = credentials;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.key, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SecretField(label: 'Username', value: c.username, onCopy: copy),
            SecretField(label: 'Password', value: c.password, onCopy: copy),
            SecretField(
              label: 'Lease ID',
              value: c.lease.leaseId,
              sensitive: false,
              onCopy: copy,
            ),
            SecretField(
              label: 'Lease duration',
              value: '${c.lease.leaseDuration.inSeconds}s',
              sensitive: false,
              onCopy: copy,
            ),
            SecretField(
              label: 'Renewable',
              value: c.lease.renewable ? 'Yes' : 'No',
              sensitive: false,
              onCopy: copy,
            ),
            const SizedBox(height: 8),
            LeaseCountdown(leaseId: c.lease.leaseId),
            const Divider(height: 24),
            _ConnectSection(credentials: c),
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

/// Ready-to-paste client command and URI. The engine and address come from
/// the server when the token may read them. Otherwise the user picks the
/// engine and types the address once per mount.
class _ConnectSection extends ConsumerWidget {
  const _ConnectSection({required this.credentials});

  final DatabaseCredentials credentials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creds = credentials;
    final detection = ref.watch(
      detectedDatabaseProvider((mount: creds.mount, role: creds.role)),
    );
    final heading = Text(
      'Connect',
      style: Theme.of(context).textTheme.titleSmall,
    );
    if (detection.isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      );
    }
    final detected = detection.value;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final storageKey = detected == null
        ? creds.mount
        : '${creds.mount}/${detected.connection}';
    final saved = resolveDbTarget(settings, storageKey, detected);
    final client = DbClient.values.byName(saved.client);
    final target = DbTarget(
      client: client,
      host: saved.host,
      port: saved.port,
      database: saved.database,
    );
    void copy(String v) => copySecret(context, ref, v);
    Future<void> save(SavedDbTarget t) => ref
        .read(settingsProvider.notifier)
        .change(
          (s) => s.copyWith(
            databaseTargets: {...s.databaseTargets, storageKey: t},
          ),
        );
    final uri = dbConnectUri(target, creds.username, creds.password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (detected?.client == null)
              SegmentedButton<DbClient>(
                segments: [
                  for (final c in DbClient.values)
                    ButtonSegment(value: c, label: Text(c.label)),
                ],
                selected: {client},
                onSelectionChanged: (s) => save(
                  saved.copyWith(
                    client: s.first.name,
                    // A port nobody changed follows the engine.
                    port: saved.port == client.defaultPort
                        ? s.first.defaultPort
                        : saved.port,
                  ),
                ),
              )
            else
              Chip(
                avatar: const Icon(Icons.auto_awesome, size: 16),
                label: Text('${client.label} · ${detected!.connection}'),
              ),
            _TargetFields(
              key: ValueKey('$storageKey|${client.name}'),
              target: saved,
              databaseLabel: client == DbClient.cqlsh ? 'Keyspace' : 'Database',
              onChanged: save,
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
        if (client == DbClient.cqlsh)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'cqlsh asks for the password. Copy it from the field above.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (uri != null)
          SecretField(
            label: 'Connection URI',
            value: uri,
            multiline: true,
            onCopy: copy,
          ),
      ],
    );
  }
}

/// Target for [storageKey]: what the user saved, else what the server
/// revealed, else the profile defaults.
SavedDbTarget resolveDbTarget(
  AppSettings settings,
  String storageKey,
  DetectedDatabase? detected,
) {
  final saved = settings.databaseTargets[storageKey];
  final fallback = DbClient.values.firstWhere(
    (c) => c.name == (saved?.client ?? settings.databaseClient),
    orElse: () => DbClient.psql,
  );
  final client = detected?.client ?? fallback;
  if (saved != null) return saved.copyWith(client: client.name);
  // The profile defaults describe one engine: they do not fit another.
  final defaultsFit = client.name == settings.databaseClient;
  return SavedDbTarget(
    client: client.name,
    host: detected?.host ?? (defaultsFit ? settings.databaseHost : ''),
    port:
        detected?.port ??
        (defaultsFit ? settings.databasePort : client.defaultPort),
    database: detected?.database ?? (defaultsFit ? settings.databaseName : ''),
  );
}

class _TargetFields extends StatefulWidget {
  const _TargetFields({
    super.key,
    required this.target,
    required this.databaseLabel,
    required this.onChanged,
  });

  final SavedDbTarget target;
  final String databaseLabel;
  final ValueChanged<SavedDbTarget> onChanged;

  @override
  State<_TargetFields> createState() => _TargetFieldsState();
}

class _TargetFieldsState extends State<_TargetFields> {
  late final _host = TextEditingController(text: widget.target.host);
  late final _port = TextEditingController(text: '${widget.target.port}');
  late final _database = TextEditingController(text: widget.target.database);
  late SavedDbTarget _edited = widget.target;
  Timer? _debounce;

  /// Every save rewrites the settings in the OS keystore: wait for a pause
  /// in typing instead of saving per keystroke.
  void _change(SavedDbTarget Function(SavedDbTarget) edit) {
    _edited = edit(_edited);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => widget.onChanged(_edited),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _host.dispose();
    _port.dispose();
    _database.dispose();
    super.dispose();
  }

  Widget _field(
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

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _field(_host, 'Host', (v) => _change((t) => t.copyWith(host: v))),
      _field(_port, 'Port', (v) {
        final port = int.tryParse(v.trim());
        if (port != null && port >= 1 && port <= 65535) {
          _change((t) => t.copyWith(port: port));
        }
      }, width: 90),
      _field(
        _database,
        widget.databaseLabel,
        (v) => _change((t) => t.copyWith(database: v)),
      ),
    ],
  );
}
