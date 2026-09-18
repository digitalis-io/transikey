import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/health_status.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../auth/presentation/profile_switcher.dart';
import '../domain/app_settings.dart';
import 'profile_dialogs.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeaturePage(
    title: 'Settings',
    child: AsyncValueView<AppSettings>(
      value: ref.watch(settingsProvider),
      // A new key rebuilds the form when another profile becomes active.
      data: (settings) => _SettingsForm(
        key: ValueKey(settings.activeProfileId),
        initial: settings,
      ),
    ),
  );
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.initial});

  final AppSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late AppSettings _draft = widget.initial;
  late final _address = TextEditingController(text: _draft.vaultAddr);
  late final _namespace = TextEditingController(text: _draft.namespace);
  late final _mounts = {
    'Database mount': TextEditingController(text: _draft.databaseMount),
    'SSH mount': TextEditingController(text: _draft.sshMount),
    'Userpass mount': TextEditingController(text: _draft.userpassMount),
    'AppRole mount': TextEditingController(text: _draft.approleMount),
    'LDAP mount': TextEditingController(text: _draft.ldapMount),
    'OIDC mount': TextEditingController(text: _draft.oidcMount),
  };
  AsyncValue<HealthStatus?> _test = const AsyncData(null);

  @override
  void dispose() {
    _address.dispose();
    _namespace.dispose();
    for (final c in _mounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  AppSettings get _current => _draft.copyWith(
    vaultAddr: _address.text.trim(),
    namespace: _namespace.text.trim(),
    databaseMount: _mounts['Database mount']!.text,
    sshMount: _mounts['SSH mount']!.text,
    userpassMount: _mounts['Userpass mount']!.text,
    approleMount: _mounts['AppRole mount']!.text,
    ldapMount: _mounts['LDAP mount']!.text,
    oidcMount: _mounts['OIDC mount']!.text,
  );

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    // Profiles are edited outside this draft: keep the latest list.
    final latest = ref.read(settingsProvider).value ?? _draft;
    await ref
        .read(settingsProvider.notifier)
        .save(
          _current.copyWith(
            profiles: latest.profiles,
            activeProfileId: latest.activeProfileId,
          ),
        );
    messenger.showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  Future<void> _testConnection() async {
    setState(() => _test = const AsyncLoading());
    final result = await AsyncValue.guard<HealthStatus?>(
      () => ref.read(vaultConnectionProvider.notifier).test(_current),
    );
    if (mounted) setState(() => _test = result);
  }

  Future<void> _setSkipTls(bool skip) async {
    if (skip) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Skip TLS verification?'),
          content: const Text(
            'The server certificate will not be checked. Anyone on the '
            'network path can read your token and secrets. Prefer importing '
            'the CA certificate instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Skip verification'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _draft = _draft.copyWith(tlsVerify: !skip));
  }

  Future<void> _importCa() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Select CA certificate (PEM)',
    );
    final file = picked?.files.single;
    if (file?.path == null) return;
    final pem = await File(file!.path!).readAsString();
    if (!mounted) return;
    if (!pem.contains('BEGIN CERTIFICATE')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not a PEM encoded certificate.')),
      );
      return;
    }
    setState(
      () => _draft = _draft.copyWith(caCertPem: pem, caCertName: file.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(String title, List<Widget> children) => Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            ...children,
          ],
        ),
      ),
    );

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            section('Server profiles', [const _ProfilesList()]),
            section(
              ref.watch(settingsProvider).value?.activeProfile == null
                  ? 'Connection'
                  : 'Connection · ${ref.watch(settingsProvider).value!.activeProfile!.name}',
              [
                TextField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Vault / OpenBao URL (VAULT_ADDR)',
                    hintText: 'https://vault.example.com:8200',
                  ),
                ),
                TextField(
                  controller: _namespace,
                  decoration: const InputDecoration(
                    labelText: 'Namespace (VAULT_NAMESPACE)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Skip TLS verification'),
                  subtitle: const Text(
                    'Insecure. Use only against test servers.',
                  ),
                  value: !_draft.tlsVerify,
                  onChanged: _setSkipTls,
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _importCa,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import CA certificate'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _draft.caCertPem == null
                            ? 'System trust store only'
                            : 'Custom CA: ${_draft.caCertName ?? 'imported'}',
                      ),
                    ),
                    if (_draft.caCertPem != null)
                      IconButton(
                        tooltip: 'Remove custom CA',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(
                          () => _draft = _draft.copyWith(
                            caCertPem: null,
                            caCertName: null,
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _test.isLoading ? null : _testConnection,
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('Test connection'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _TestResult(_test)),
                  ],
                ),
              ],
            ),
            section('Security', [
              _NumberSetting(
                label: 'Lock after inactivity (seconds, 0 = never)',
                value: _draft.inactivityTimeoutSeconds,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(inactivityTimeoutSeconds: v),
                ),
              ),
              _NumberSetting(
                label: 'Clear clipboard after (seconds, 0 = never)',
                value: _draft.clipboardClearSeconds,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(clipboardClearSeconds: v),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Biometric unlock'),
                subtitle: const Text(
                  'Touch ID or Windows Hello, when available',
                ),
                value: _draft.biometricUnlock,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(biometricUnlock: v),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Blur window when it loses focus'),
                value: _draft.blurOnFocusLoss,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(blurOnFocusLoss: v),
                ),
              ),
            ]),
            section('Appearance', [
              SegmentedButton<AppThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: AppThemeMode.system,
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    label: Text('Light'),
                  ),
                  ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
                ],
                selected: {_draft.themeMode},
                onSelectionChanged: (s) => setState(
                  () => _draft = _draft.copyWith(themeMode: s.first),
                ),
              ),
            ]),
            section('Mount paths', [
              for (final e in _mounts.entries)
                TextField(
                  controller: e.value,
                  decoration: InputDecoration(labelText: e.key),
                ),
            ]),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestResult extends StatelessWidget {
  const _TestResult(this.result);

  final AsyncValue<HealthStatus?> result;

  @override
  Widget build(BuildContext context) {
    if (result.isLoading) return const LinearProgressIndicator();
    if (result.hasError) {
      return Text(
        errorMessage(result.error!),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    final health = result.value;
    if (health == null) return const SizedBox.shrink();
    return Text(
      'OK · v${health.version} · ${health.sealed ? 'sealed' : 'unsealed'}'
      '${health.clusterName.isEmpty ? '' : ' · ${health.clusterName}'}',
    );
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: '$value',
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    onChanged: (v) {
      final parsed = int.tryParse(v.trim());
      if (parsed != null && parsed >= 0) onChanged(parsed);
    },
  );
}

class _ProfilesList extends ConsumerWidget {
  const _ProfilesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final notifier = ref.read(settingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (settings.profiles.isEmpty)
          const Text(
            'No profiles yet. Save the current server to switch back to it '
            'later with its namespace, TLS, mounts and connect targets.',
          ),
        for (final p in settings.profiles)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ProfileDot(p.color, size: 16),
            title: Text(
              p.id == settings.activeProfileId ? '${p.name} (active)' : p.name,
            ),
            subtitle: Text(
              p.namespace.isEmpty
                  ? p.vaultAddr
                  : '${p.vaultAddr} · ${p.namespace}',
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                if (p.id != settings.activeProfileId)
                  TextButton(
                    onPressed: () => switchServerProfile(context, ref, p),
                    child: const Text('Switch'),
                  ),
                IconButton(
                  tooltip: 'Rename or recolour',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showProfileDialog(context, ref, existing: p),
                ),
                IconButton(
                  tooltip: 'Delete profile',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => notifier.deleteProfile(p.id),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: settings.isConfigured
                ? () => showProfileDialog(context, ref)
                : null,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(
              settings.activeProfile == null
                  ? 'Save current server as profile'
                  : 'Save a copy as new profile',
            ),
          ),
        ),
      ],
    );
  }
}
