import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/clipboard_actions.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/resizable_split.dart';
import '../../../core/widgets/role_picker.dart';
import '../../../core/widgets/secret_field.dart';
import '../../leases/presentation/lease_countdown.dart';
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

  @override
  void dispose() {
    for (final c in [_ip, _username, _publicKey, _principals]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPublicKey() async {
    final picked = await FilePicker.pickFiles(dialogTitle: 'Select public key');
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
            roles: ref.watch(sshRolesProvider),
            selected: _role,
            onSelected: (r) {
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
                        _ResultView(result),
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
                        _ResultView(result),
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
                        _ResultView(result),
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

  Widget _action(String label, IconData icon, VoidCallback? onPressed) => Align(
    alignment: Alignment.centerLeft,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(_role == null ? 'Select a role' : label),
    ),
  );
}

class _ResultView extends ConsumerWidget {
  const _ResultView(this.result);

  final AsyncValue<SshResult?> result;

  Future<void> _download(BuildContext context, String certificate) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save signed certificate',
      fileName: 'id_key-cert.pub',
    );
    if (path == null) return;
    await File(path).writeAsString('$certificate\n');
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
                  onPressed: () => _download(context, certificate.signedKey),
                  icon: const Icon(Icons.download),
                  label: const Text('Download certificate'),
                ),
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
