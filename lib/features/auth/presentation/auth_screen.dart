import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/errors/vault_exception.dart';
import '../../../core/utils/cli_environment.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../leases/presentation/leases_provider.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/domain/server_profile.dart';
import '../../settings/presentation/profile_dialogs.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/vault_session.dart';
import 'auth_provider.dart';
import 'profile_switcher.dart';
import 'session_provider.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vaultSessionProvider);
    return FeaturePage(
      title: 'Authentication',
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: switch (session) {
            SessionAuthenticated(:final session) => _SessionCard(session),
            SessionLocked(:final session) => _SessionCard(session),
            SessionUnauthenticated(:final reason) => _LoginForm(reason: reason),
          },
        ),
      ),
    );
  }
}

String _cliImportLabel(CliEnvironment cli) {
  final parts = [
    if (cli.addressSource != null) cli.addressSource!,
    if (cli.tokenSource != null) cli.tokenSource!,
  ];
  return 'Import from CLI (${parts.join(' + ')})';
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({this.reason});

  final String? reason;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _namespace = TextEditingController();
  final _token = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _roleId = TextEditingController();
  final _secretId = TextEditingController();
  final _oidcRole = TextEditingController();
  AuthMethod _method = AuthMethod.token;
  bool _prefilled = false;

  /// Fills the form from the live settings: on first build and whenever
  /// another server profile becomes active.
  void _prefill(AppSettings settings) {
    _address.text = settings.vaultAddr;
    _namespace.text = settings.namespace;
    _username.text = settings.lastUsername;
    _method = AuthMethod.values.firstWhere(
      (m) => m.name == settings.lastAuthMethod,
      orElse: () => _method,
    );
  }

  @override
  void dispose() {
    for (final c in [
      _address,
      _namespace,
      _token,
      _username,
      _password,
      _roleId,
      _oidcRole,
      _secretId,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills the form from the CLI environment. The token goes into the
  /// masked field only; nothing is stored or sent until Sign in is pressed.
  Future<void> _importFromCli() async {
    final cli = ref.read(cliEnvironmentProvider);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(settingsProvider.notifier);
    final imported = <String>[];

    if (cli.address != null) {
      final active = ref.read(settingsProvider).value?.activeProfile;
      if (active != null && active.vaultAddr.trim() != cli.address) {
        await notifier.detachProfile();
      }
      final ca = cli.readCaCert();
      await notifier.change(
        (s) => s.copyWith(
          tlsVerify: !cli.skipVerify,
          caCertPem: ca ?? s.caCertPem,
          caCertName: ca == null ? s.caCertName : cli.caCertPath,
        ),
      );
      imported.add('address from ${cli.addressSource}');
      if (cli.namespace != null) imported.add('namespace');
      if (ca != null) imported.add('CA certificate');
      if (cli.skipVerify) imported.add('TLS verification OFF');
    }
    final token = cli.readToken();
    if (token != null) imported.add('token from ${cli.tokenSource}');
    if (!mounted) return;

    setState(() {
      if (cli.address != null) {
        _address.text = cli.address!;
        _namespace.text = cli.namespace ?? '';
      }
      if (token != null) {
        _method = AuthMethod.token;
        _token.text = token;
      }
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          imported.isEmpty
              ? 'Nothing to import.'
              : 'Imported ${imported.join(', ')}. Press Sign in to continue.',
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final settings = ref.read(settingsProvider.notifier);
    final address = _address.text.trim();
    // A different address is a different server: never overwrite the
    // active profile with it.
    final active = ref.read(settingsProvider).value?.activeProfile;
    if (active != null && active.vaultAddr.trim() != address) {
      await settings.detachProfile();
    }
    await settings.change(
      (s) => s.copyWith(
        vaultAddr: address,
        namespace: _namespace.text.trim(),
        lastAuthMethod: _method.name,
        lastUsername: switch (_method) {
          AuthMethod.userpass || AuthMethod.ldap => _username.text.trim(),
          _ => '',
        },
      ),
    );
    final auth = ref.read(vaultAuthProvider.notifier);
    switch (_method) {
      case AuthMethod.token:
        await auth.loginWithToken(_token.text);
      case AuthMethod.userpass:
        await auth.loginWithUserpass(_username.text, _password.text);
      case AuthMethod.ldap:
        await auth.loginWithLdap(_username.text, _password.text);
      case AuthMethod.oidc:
        await auth.loginWithOidc(_oidcRole.text);
      case AuthMethod.approle:
        await auth.loginWithAppRole(_roleId.text, _secretId.text);
    }
    // A successful login replaces this form, disposing its controllers.
    if (!mounted) return;
    // Secrets leave the form as soon as the attempt is over.
    _token.clear();
    _password.clear();
    _secretId.clear();
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final login = ref.watch(vaultAuthProvider);
    final settings = ref.watch(settingsProvider).value;
    if (!_prefilled && settings != null) {
      _prefilled = true;
      _prefill(settings);
    }
    ref.listen(settingsProvider.select((s) => s.value?.activeProfileId), (
      previous,
      next,
    ) {
      final latest = ref.read(settingsProvider).value;
      if (next != null && latest != null) setState(() => _prefill(latest));
    });
    final profiles = settings?.profiles ?? const <ServerProfile>[];

    Widget secret(TextEditingController c, String label) => TextFormField(
      controller: c,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(labelText: label),
      validator: _required,
      onFieldSubmitted: (_) => _submit(),
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          if (profiles.isNotEmpty)
            DropdownButtonFormField<String?>(
              value: settings?.activeProfileId,
              // Bounded item width, so the address can ellipsize.
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Server'),
              items: [
                const DropdownMenuItem<String?>(child: Text('New server…')),
                for (final p in profiles)
                  DropdownMenuItem<String?>(
                    value: p.id,
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: p.color == 0
                              ? Theme.of(context).colorScheme.outline
                              : Color(p.color),
                        ),
                        const SizedBox(width: 8),
                        Text(p.name),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            p.vaultAddr,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: login.isLoading
                  ? null
                  : (id) async {
                      final notifier = ref.read(settingsProvider.notifier);
                      if (id == null) {
                        await notifier.detachProfile();
                        setState(() {
                          _address.clear();
                          _namespace.clear();
                          _username.clear();
                        });
                        return;
                      }
                      final target = profiles.firstWhere((p) => p.id == id);
                      await switchServerProfile(context, ref, target);
                    },
            ),
          if (ref.watch(cliEnvironmentProvider).hasAnything)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: login.isLoading ? null : _importFromCli,
                icon: const Icon(Icons.terminal),
                label: Text(_cliImportLabel(ref.watch(cliEnvironmentProvider))),
              ),
            ),
          if (widget.reason != null)
            ErrorBanner(error: VaultException(widget.reason!)),
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Vault / OpenBao address',
              hintText: 'https://vault.example.com:8200',
            ),
            validator: (v) {
              final uri = Uri.tryParse(v?.trim() ?? '');
              return uri == null || !uri.hasScheme || uri.host.isEmpty
                  ? 'Enter a full URL'
                  : null;
            },
          ),
          TextFormField(
            controller: _namespace,
            decoration: const InputDecoration(
              labelText: 'Namespace (optional)',
            ),
          ),
          SegmentedButton<AuthMethod>(
            segments: const [
              ButtonSegment(value: AuthMethod.token, label: Text('Token')),
              ButtonSegment(
                value: AuthMethod.userpass,
                label: Text('Userpass'),
              ),
              ButtonSegment(value: AuthMethod.ldap, label: Text('LDAP')),
              ButtonSegment(value: AuthMethod.oidc, label: Text('OIDC')),
              ButtonSegment(value: AuthMethod.approle, label: Text('AppRole')),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          ...switch (_method) {
            AuthMethod.token => [secret(_token, 'Token')],
            AuthMethod.userpass || AuthMethod.ldap => [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: _required,
              ),
              secret(_password, 'Password'),
            ],
            AuthMethod.oidc => [
              TextFormField(
                controller: _oidcRole,
                decoration: const InputDecoration(
                  labelText: 'Role (optional)',
                  hintText: 'Empty = the default role of the OIDC mount',
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              Text(
                login.isLoading
                    ? 'Finish signing in in your browser…'
                    : 'Your browser opens for the identity provider login. '
                          'The role must allow the redirect URI '
                          'http://localhost:8250/oidc/callback.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            AuthMethod.approle => [
              TextFormField(
                controller: _roleId,
                decoration: const InputDecoration(labelText: 'Role ID'),
                validator: _required,
              ),
              secret(_secretId, 'Secret ID'),
            ],
          },
          if (login.hasError && !login.isLoading)
            ErrorBanner(error: login.error!),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: login.isLoading ? null : _submit,
              icon: login.isLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(
                _method == AuthMethod.oidc ? 'Sign in with browser' : 'Sign in',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard(this.session);

  final VaultSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final left = session.remaining(now);
    final notifier = ref.read(vaultSessionProvider.notifier);
    final settings = ref.watch(settingsProvider).value;
    final theme = Theme.of(context);

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signed in', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            row(
              'Server',
              settings?.activeProfile?.name ?? settings?.vaultAddr ?? '',
            ),
            row('Identity', session.displayName),
            row('Method', session.method.name),
            row('Policies', session.policies.join(', ')),
            row(
              'Token TTL',
              left == null ? 'Never expires' : formatDuration(left),
            ),
            row('Renewable', session.renewable ? 'Yes' : 'No'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                if (session.renewable)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await notifier.renew();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Token renewed')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(errorMessage(e))),
                        );
                      }
                    },
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Renew token'),
                  ),
                if (settings != null && settings.activeProfile == null)
                  OutlinedButton.icon(
                    onPressed: () => showProfileDialog(context, ref),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save server profile'),
                  ),
                OutlinedButton.icon(
                  onPressed: notifier.lock,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Lock'),
                ),
                FilledButton.tonalIcon(
                  onPressed: notifier.logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
