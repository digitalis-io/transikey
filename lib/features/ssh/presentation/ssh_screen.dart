import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/clipboard_actions.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/utils/home_paths.dart';
import '../../../core/utils/ssh_connect_command.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/resizable_split.dart';
import '../../../core/widgets/role_picker.dart';
import '../../../core/widgets/secret_field.dart';
import '../../leases/presentation/lease_countdown.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/ssh_repository.dart';
import 'ssh_provider.dart';

class SshScreen extends ConsumerStatefulWidget {
  const SshScreen({super.key});

  @override
  ConsumerState<SshScreen> createState() => _SshScreenState();
}

class _SshScreenState extends ConsumerState<SshScreen> {
  final _ip = TextEditingController();
  final _username = TextEditingController();
  final _publicKey = TextEditingController();
  final _principals = TextEditingController();
  String? _role;
  String? _certPath;

  @override
  void dispose() {
    for (final c in [_ip, _username, _publicKey, _principals]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPublicKey() async {
    // Native dialogs hide dotfiles, so start inside ~/.ssh when it exists.
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Select public key',
      initialDirectory: existingSshDirectory(),
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    if (content.contains('PRIVATE KEY')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That is a private key. Select the .pub file.'),
        ),
      );
      return;
    }
    _publicKey.text = content.trim();
    // Remember the matching private key for the connect command.
    await ref
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(sshKeyPath: privateKeyPathFor(path)));
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(sshCredentialsProvider);
    final notifier = ref.read(sshCredentialsProvider.notifier);
    final busy = result.isLoading;
    final hasRole = _role != null;

    return DefaultTabController(
      length: 3,
      child: FeaturePage(
        title: 'SSH Access',
        scrollable: false,
        child: ResizableSplit(
          left: RolePicker(
            groups: ref
                .watch(sshRolesProvider)
                .whenData((roles) => [RoleGroup(roles: roles)]),
            selected: _role == null ? null : ('', _role!),
            onSelected: (_, r) {
              if (r == _role) return;
              // Results of the previous role must not linger on screen.
              notifier.clear();
              setState(() => _role = r);
            },
            onRefresh: () => ref.invalidate(sshRolesProvider),
          ),
          right: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  onTap: (_) => notifier.clear(),
                  tabs: const [
                    Tab(text: 'One-time password'),
                    Tab(text: 'Sign public key'),
                    Tab(text: 'Attempt token'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _tab([
                        TextField(
                          controller: _ip,
                          decoration: const InputDecoration(
                            labelText: 'Target IP address',
                          ),
                        ),
                        TextField(
                          controller: _username,
                          decoration: const InputDecoration(
                            labelText: 'Username (optional, role default)',
                          ),
                        ),
                        _action(
                          'Generate OTP',
                          Icons.password,
                          !hasRole || busy
                              ? null
                              : () => notifier.requestOtp(
                                  _role!,
                                  ip: _ip.text,
                                  username: _username.text,
                                ),
                        ),
                        _ResultView(
                          result,
                          certPath: _certPath,
                          onCertificateSaved: (p) =>
                              setState(() => _certPath = p),
                        ),
                      ]),
                      _tab([
                        TextField(
                          controller: _publicKey,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Public key',
                            hintText: 'ssh-ed25519 AAAA…',
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _loadPublicKey,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload public key'),
                          ),
                        ),
                        TextField(
                          controller: _principals,
                          decoration: const InputDecoration(
                            labelText: 'Valid principals (optional)',
                          ),
                        ),
                        _action(
                          'Sign key',
                          Icons.verified_user_outlined,
                          !hasRole || busy
                              ? null
                              : () => notifier.sign(
                                  _role!,
                                  _publicKey.text,
                                  validPrincipals: _principals.text,
                                ),
                        ),
                        _ResultView(
                          result,
                          certPath: _certPath,
                          onCertificateSaved: (p) =>
                              setState(() => _certPath = p),
                        ),
                      ]),
                      _tab([
                        const Text(
                          'Requests a token from ssh/get-attempt-token for the '
                          'selected role. Requires server-side support for '
                          'this endpoint.',
                        ),
                        _action(
                          'Get attempt token',
                          Icons.token_outlined,
                          !hasRole || busy
                              ? null
                              : () => notifier.requestAttemptToken({
                                  'role': _role,
                                }),
                        ),
                        _ResultView(
                          result,
                          certPath: _certPath,
                          onCertificateSaved: (p) =>
                              setState(() => _certPath = p),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: children,
    ),
  );

  Widget _action(String label, IconData icon, VoidCallback? onPressed) => Row(
    children: [
      FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(_role == null ? label : '$label ($_role)'),
      ),
      if (_role == null) ...[
        const SizedBox(width: 12),
        Text(
          'Pick a role in the list on the left first.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ],
  );
}

class _ResultView extends ConsumerWidget {
  const _ResultView(
    this.result, {
    required this.certPath,
    required this.onCertificateSaved,
  });

  final AsyncValue<SshResult?> result;
  final String? certPath;
  final ValueChanged<String> onCertificateSaved;

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    String certificate,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final keyPath = ref.read(settingsProvider).value?.sshKeyPath ?? 'id_key';
    final keyName = keyPath.split(RegExp(r'[\\/]')).last;
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save signed certificate',
      fileName: '$keyName-cert.pub',
      // Save beside the private key; ~/.ssh is hidden in native dialogs.
      initialDirectory: parentDirectoryOf(keyPath) ?? existingSshDirectory(),
    );
    if (path == null) return;
    await File(path).writeAsString('$certificate\n');
    onCertificateSaved(path);
    messenger.showSnackBar(SnackBar(content: Text('Saved to $path')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void copy(String v) => copySecret(context, ref, v);
    SecretField plain(String label, String value) =>
        SecretField(label: label, value: value, sensitive: false, onCopy: copy);

    return AsyncValueView<SshResult?>(
      value: result,
      empty: 'Results appear here.',
      data: (r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: switch (r!) {
              SshOtpResult(:final credentials) => [
                plain('Username', credentials.username),
                SecretField(label: 'OTP', value: credentials.otp, onCopy: copy),
                plain('Target', '${credentials.ip}:${credentials.port}'),
                plain(
                  'Lease duration',
                  '${credentials.lease.leaseDuration.inSeconds}s',
                ),
                if (credentials.lease.leaseId.isNotEmpty)
                  LeaseCountdown(leaseId: credentials.lease.leaseId),
                const Divider(height: 24),
                _SshConnectSection(
                  otp: credentials.otp,
                  suggestedUser: credentials.username,
                ),
              ],
              SshSignedResult(:final certificate) => [
                plain('Serial number', certificate.serialNumber),
                SecretField(
                  label: 'Certificate',
                  value: certificate.signedKey,
                  multiline: true,
                  onCopy: copy,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _download(context, ref, certificate.signedKey),
                  icon: const Icon(Icons.download),
                  label: const Text('Download certificate'),
                ),
                const Divider(height: 24),
                _SshConnectSection(certPath: certPath),
              ],
              SshAttemptTokenResult(:final token, :final issuedAt) => [
                SecretField(label: 'Token', value: token.token, onCopy: copy),
                for (final e in token.metadata.entries) plain(e.key, e.value),
                plain(
                  'Expires',
                  token.leaseDuration == Duration.zero
                      ? 'Not reported'
                      : '${issuedAt.add(token.leaseDuration).toLocal()} '
                            '(${formatDuration(token.leaseDuration)})',
                ),
              ],
            },
          ),
        ),
      ),
    );
  }
}

/// Ready-to-paste ssh commands. User, host, port and key path are the
/// user's own settings: Vault only knows the IP an OTP was issued for.
class _SshConnectSection extends ConsumerStatefulWidget {
  const _SshConnectSection({this.otp, this.certPath, this.suggestedUser});

  /// Set for an OTP result.
  final String? otp;

  /// Set for a signed certificate result (path of the saved certificate).
  final String? certPath;

  /// Username the role assigned, used when the setting is empty.
  final String? suggestedUser;

  @override
  ConsumerState<_SshConnectSection> createState() => _SshConnectSectionState();
}

class _SshConnectSectionState extends ConsumerState<_SshConnectSection> {
  late final TextEditingController _user;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _key;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider).value ?? const AppSettings();
    _user = TextEditingController(
      text: s.sshUser.isEmpty ? widget.suggestedUser ?? '' : s.sshUser,
    );
    _host = TextEditingController(text: s.sshHost);
    _port = TextEditingController(text: '${s.sshPort}');
    _key = TextEditingController(text: s.sshKeyPath);
  }

  @override
  void didUpdateWidget(_SshConnectSection old) {
    super.didUpdateWidget(old);
    final keyPath = ref.read(settingsProvider).value?.sshKeyPath;
    if (keyPath != null && keyPath != _key.text) _key.text = keyPath;
  }

  @override
  void dispose() {
    for (final c in [_user, _host, _port, _key]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(AppSettings Function(AppSettings) change) =>
      ref.read(settingsProvider.notifier).change(change);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).value ?? const AppSettings();
    final target = SshTarget(
      user: _user.text,
      host: s.sshHost,
      port: s.sshPort,
    );
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

    final isOtp = widget.otp != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connect', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            field(
              _user,
              'User',
              (v) => _save((x) => x.copyWith(sshUser: v)),
              width: 120,
            ),
            field(_host, 'Host', (v) => _save((x) => x.copyWith(sshHost: v))),
            field(_port, 'Port', (v) {
              final port = int.tryParse(v.trim());
              if (port != null) _save((x) => x.copyWith(sshPort: port));
            }, width: 90),
            if (!isOtp)
              field(
                _key,
                'Private key',
                (v) => _save((x) => x.copyWith(sshKeyPath: v)),
                width: 260,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isOtp) ...[
          SecretField(
            label: 'ssh (paste OTP)',
            value: sshOtpCommand(target),
            sensitive: false,
            multiline: true,
            onCopy: copy,
          ),
          SecretField(
            label: 'sshpass one-liner',
            value: sshOtpSshpassCommand(target, widget.otp!),
            multiline: true,
            onCopy: copy,
          ),
        ] else ...[
          SecretField(
            label: 'ssh',
            value: sshCertCommand(
              target,
              s.sshKeyPath,
              certPath: widget.certPath,
            ),
            sensitive: false,
            multiline: true,
            onCopy: copy,
          ),
          if (widget.certPath == null)
            Text(
              'Download the certificate next to the key as '
              '<key>-cert.pub and ssh picks it up automatically.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}
