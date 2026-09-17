import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/vault_exception.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../leases/presentation/leases_provider.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/vault_session.dart';
import 'auth_provider.dart';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final settings = ref.read(settingsProvider.notifier);
    await settings.change(
      (s) => s.copyWith(
        vaultAddr: _address.text.trim(),
        namespace: _namespace.text.trim(),
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
      _address.text = settings.vaultAddr;
      _namespace.text = settings.namespace;
    }

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
