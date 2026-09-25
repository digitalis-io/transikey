import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/clipboard_actions.dart';
import '../../../core/models/kubernetes_credentials.dart';
import '../../../core/utils/home_paths.dart';
import '../../../core/utils/kubeconfig.dart';
import '../../../core/utils/private_file.dart';
import '../../../core/widgets/secret_field.dart';
import '../../leases/presentation/lease_countdown.dart';
import '../../settings/domain/server_profile.dart';
import '../../settings/presentation/settings_provider.dart';
import 'kubernetes_provider.dart';

/// Picks where to save a kubeconfig. Null when the user cancels. Tests
/// replace it: native dialogs do not run under `flutter test`.
final kubeconfigSaveLocationProvider =
    Provider<Future<String?> Function(String fileName)>(
      (ref) =>
          (fileName) => FilePicker.saveFile(
            dialogTitle: 'Save kubeconfig',
            fileName: fileName,
            // ~/.kube is hidden in native dialogs: start inside it.
            initialDirectory: existingKubeDirectory(),
          ),
    );

/// Issued token, titled `mount/role`.
class KubernetesCredentialsCard extends ConsumerWidget {
  const KubernetesCredentialsCard(this.credentials, {super.key});

  final KubernetesCredentials credentials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void copy(String v) => copySecret(context, ref, v);
    SecretField plain(String label, String value) =>
        SecretField(label: label, value: value, sensitive: false, onCopy: copy);
    final c = credentials;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.key, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            plain('Service account', c.serviceAccountName),
            plain('Namespace', c.serviceAccountNamespace),
            SecretField(
              label: 'Token',
              value: c.serviceAccountToken,
              multiline: true,
              onCopy: copy,
            ),
            plain('Lease ID', c.lease.leaseId),
            plain('Lease duration', '${c.lease.leaseDuration.inSeconds}s'),
            const SizedBox(height: 8),
            LeaseCountdown(leaseId: c.lease.leaseId),
            const Divider(height: 24),
            // A new token must not reuse the file saved for the old one.
            _ConnectSection(key: ObjectKey(c), credentials: c),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: ref.read(kubernetesCredentialsProvider.notifier).clear,
              icon: const Icon(Icons.visibility_off),
              label: const Text('Clear from screen'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kubeconfig for the token. Vault does not return the API server, so the
/// address and CA are typed once per mount and remembered.
class _ConnectSection extends ConsumerStatefulWidget {
  const _ConnectSection({super.key, required this.credentials});

  final KubernetesCredentials credentials;

  @override
  ConsumerState<_ConnectSection> createState() => _ConnectSectionState();
}

class _ConnectSectionState extends ConsumerState<_ConnectSection> {
  String get _mount => widget.credentials.mount;

  late final SavedKubeTarget _initial =
      ref.read(settingsProvider).value?.kubernetesTargets[_mount] ??
      const SavedKubeTarget();
  late final _server = TextEditingController(text: _initial.server);
  late final _caPath = TextEditingController(text: _initial.caPath);
  // Held on to: dispose may still save, and ref is gone by then.
  late final SettingsNotifier _settings;
  Timer? _debounce;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(settingsProvider.notifier);
  }

  @override
  void dispose() {
    // Keep what was typed even when the card goes before the pause ends.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _persist();
    }
    _server.dispose();
    _caPath.dispose();
    super.dispose();
  }

  SavedKubeTarget get _target =>
      SavedKubeTarget(server: _server.text.trim(), caPath: _caPath.text.trim());

  bool get _serverValid {
    final uri = Uri.tryParse(_target.server);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  String get _yaml => kubeconfigYaml(
    widget.credentials,
    server: _target.server,
    caPath: _target.caPath,
  );

  void _persist() {
    final target = _target;
    _settings.change(
      (s) => s.copyWith(
        kubernetesTargets: {...s.kubernetesTargets, _mount: target},
      ),
    );
  }

  /// Every save rewrites the settings in the OS keystore: wait for a pause
  /// in typing instead of saving per keystroke.
  void _changed() {
    setState(() => _savedPath = null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _persist);
  }

  Future<void> _pickCa() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Select cluster CA certificate',
      initialDirectory: existingKubeDirectory(),
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    _caPath.text = path;
    _changed();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final c = widget.credentials;
    final path = await ref.read(kubeconfigSaveLocationProvider)(
      'kubeconfig-${c.mount}-${c.role}.yaml'.replaceAll('/', '-'),
    );
    if (path == null) return;
    try {
      await writePrivateFile(path, _yaml);
    } on FileSystemException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save: ${e.message}')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _savedPath = path);
    messenger.showSnackBar(SnackBar(content: Text('Saved to $path')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedPath = _savedPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connect', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _server,
                decoration: const InputDecoration(
                  labelText: 'API server URL',
                  hintText: 'https://k8s.example.com:6443',
                ),
                onChanged: (_) => _changed(),
              ),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _caPath,
                decoration: InputDecoration(
                  labelText: 'CA certificate path (optional)',
                  suffixIcon: IconButton(
                    tooltip: 'Choose file',
                    icon: const Icon(Icons.folder_open),
                    onPressed: _pickCa,
                  ),
                ),
                onChanged: (_) => _changed(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _serverValid
                  ? () => copySecret(context, ref, _yaml)
                  : null,
              icon: const Icon(Icons.copy),
              label: const Text('Copy kubeconfig'),
            ),
            OutlinedButton.icon(
              onPressed: _serverValid ? _save : null,
              icon: const Icon(Icons.save_alt),
              label: const Text('Save kubeconfig'),
            ),
          ],
        ),
        if (!_serverValid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Enter the API server URL (https://…) first.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (savedPath != null) ...[
          const SizedBox(height: 8),
          SecretField(
            label: 'kubectl command',
            value: kubectlCommand(
              savedPath,
              widget.credentials.serviceAccountNamespace,
            ),
            sensitive: false,
            multiline: true,
            onCopy: (v) => copySecret(context, ref, v),
          ),
        ],
      ],
    );
  }
}
