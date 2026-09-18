import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/clipboard_actions.dart';
import '../../../app/providers/deep_link_provider.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/utils/share_link.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/secret_field.dart';
import '../../auth/domain/vault_session.dart';
import '../../auth/presentation/session_provider.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/sharing_repository.dart';
import 'sharing_provider.dart';

const _ttlChoices = <String, Duration>{
  '5 minutes': Duration(minutes: 5),
  '30 minutes': Duration(minutes: 30),
  '1 hour': Duration(hours: 1),
  '24 hours': Duration(hours: 24),
  '7 days': Duration(days: 7),
};

/// Accepts a JSON object, or wraps free text as `{"secret": "<text>"}`.
Map<String, dynamic> parseSecretPayload(String input) {
  final text = input.trim();
  if (text.isEmpty) return const {};
  if (text.startsWith('{')) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Not JSON after all: share it as plain text.
    }
  }
  return {'secret': text};
}

class SharingScreen extends ConsumerStatefulWidget {
  const SharingScreen({super.key});

  @override
  ConsumerState<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends ConsumerState<SharingScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this);
  final _unwrapServer = TextEditingController();
  final _unwrapNamespace = TextEditingController();
  final _payload = TextEditingController();
  final _wrappingToken = TextEditingController();
  final _cubbyPath = TextEditingController();
  final _cubbyData = TextEditingController();
  Duration _ttl = _ttlChoices.values.elementAt(1);

  @override
  void initState() {
    super.initState();
    // A link that launched the app is already waiting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Signed out, Unwrap is the only tab that can do anything.
      if (ref.read(vaultSessionProvider) is! SessionAuthenticated) {
        _tabs.index = 1;
      }
      _consumeShareLink();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _payload,
      _wrappingToken,
      _unwrapServer,
      _unwrapNamespace,
      _cubbyPath,
      _cubbyData,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Prefills the Unwrap tab from a `transikey://unwrap` link. Nothing is
  /// sent until the user presses Unwrap.
  void _consumeShareLink() {
    if (!mounted) return;
    final link = ref.read(pendingShareLinkProvider.notifier).take();
    if (link == null) return;
    ref.read(secretSharingProvider.notifier).clear();
    _wrappingToken.text = link.token;
    _unwrapServer.text = link.address;
    _unwrapNamespace.text = link.namespace;
    _tabs.animateTo(1);
  }

  Future<void> _unwrap() async {
    final server = _unwrapServer.text.trim();
    final configured = ref.read(settingsProvider).value?.vaultAddr.trim() ?? '';
    if (server.isNotEmpty && server != configured) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unwrap from another server?'),
          content: Text(
            'This secret lives on a server that is not your configured one:'
            '\n\n$server\n\nContinue only if you trust the sender and '
            'recognise this address.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Unwrap'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await ref
        .read(secretSharingProvider.notifier)
        .unwrap(
          _wrappingToken.text,
          address: server,
          namespace: _unwrapNamespace.text,
        );
    if (!mounted) return;
    _wrappingToken.clear();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(secretSharingProvider);
    final notifier = ref.read(secretSharingProvider.notifier);
    final busy = result.isLoading;
    // Unwrapping needs no session (that is the point of a share link);
    // wrapping and the cubbyhole belong to a token.
    final signedIn = ref.watch(vaultSessionProvider) is SessionAuthenticated;
    final locked = busy || !signedIn;
    ref.listen(pendingShareLinkProvider, (_, link) {
      if (link != null) _consumeShareLink();
    });

    return FeaturePage(
      title: 'Secret Sharing',
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabs,
            onTap: (_) => notifier.clear(),
            tabs: const [
              Tab(text: 'Wrap'),
              Tab(text: 'Unwrap'),
              Tab(text: 'Cubbyhole'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _tab([
                  if (!signedIn) const _SignInHint('wrap a secret'),
                  TextField(
                    controller: _payload,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Secret (text or JSON object)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  DropdownButtonFormField<Duration>(
                    value: _ttl,
                    decoration: const InputDecoration(
                      labelText: 'Time to live',
                    ),
                    items: [
                      for (final e in _ttlChoices.entries)
                        DropdownMenuItem(value: e.value, child: Text(e.key)),
                    ],
                    onChanged: (v) => setState(() => _ttl = v ?? _ttl),
                  ),
                  _button('Wrap secret', Icons.lock, locked, () async {
                    await notifier.wrap(
                      parseSecretPayload(_payload.text),
                      _ttl,
                    );
                    if (!mounted) return;
                    if (!ref.read(secretSharingProvider).hasError) {
                      _payload.clear();
                    }
                  }),
                  _ResultView(result),
                ]),
                _tab([
                  TextField(
                    controller: _wrappingToken,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Wrapping token',
                    ),
                  ),
                  const Text(
                    'A wrapping token works once. Unwrapping consumes it.',
                  ),
                  TextField(
                    controller: _unwrapServer,
                    decoration: const InputDecoration(
                      labelText: 'Server (optional)',
                      hintText: 'Empty = your configured server',
                    ),
                  ),
                  TextField(
                    controller: _unwrapNamespace,
                    decoration: const InputDecoration(
                      labelText: 'Namespace (optional)',
                    ),
                  ),
                  _button('Unwrap', Icons.lock_open, busy, _unwrap),
                  _ResultView(result),
                ]),
                _tab([
                  if (!signedIn) const _SignInHint('use the cubbyhole'),
                  TextField(
                    controller: _cubbyPath,
                    decoration: const InputDecoration(
                      labelText: 'Path',
                      prefixText: 'cubbyhole/',
                    ),
                  ),
                  TextField(
                    controller: _cubbyData,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Secret to store (text or JSON object)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: locked
                            ? null
                            : () async {
                                await notifier.cubbyholeStore(
                                  _cubbyPath.text,
                                  parseSecretPayload(_cubbyData.text),
                                );
                                if (!mounted) return;
                                _cubbyData.clear();
                              },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Store'),
                      ),
                      OutlinedButton.icon(
                        onPressed: locked
                            ? null
                            : () => notifier.cubbyholeRetrieve(_cubbyPath.text),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Retrieve'),
                      ),
                      OutlinedButton.icon(
                        onPressed: locked
                            ? null
                            : () => notifier.cubbyholeDelete(_cubbyPath.text),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                  if (signedIn)
                    _CubbyholeKeys(
                      onSelected: (k) => setState(() => _cubbyPath.text = k),
                    ),
                  _ResultView(result),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.only(top: 16),
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: children,
        ),
      ),
    ),
  );

  Widget _button(
    String label,
    IconData icon,
    bool busy,
    Future<void> Function() onPressed,
  ) => Align(
    alignment: Alignment.centerLeft,
    child: FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

/// Copy a one-time share link or the equivalent CLI command.
class _ShareActions extends ConsumerWidget {
  const _ShareActions({required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final link = ShareLink(
      address: settings?.vaultAddr.trim() ?? '',
      namespace: settings?.namespace.trim() ?? '',
      token: token,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => copySecret(context, ref, link.toUri().toString()),
          icon: const Icon(Icons.link),
          label: const Text('Copy share link'),
        ),
        OutlinedButton.icon(
          onPressed: () => copySecret(context, ref, link.toCliCommand()),
          icon: const Icon(Icons.terminal),
          label: const Text('Copy CLI command'),
        ),
      ],
    );
  }
}

class _SignInHint extends StatelessWidget {
  const _SignInHint(this.action);

  final String action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sign in to $action. Unwrapping works without signing in.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CubbyholeKeys extends ConsumerWidget {
  const _CubbyholeKeys({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(cubbyholeKeysProvider).value ?? const <String>[];
    if (keys.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        for (final key in keys)
          ActionChip(label: Text(key), onPressed: () => onSelected(key)),
      ],
    );
  }
}

class _ResultView extends ConsumerWidget {
  const _ResultView(this.result);

  final AsyncValue<SharingResult?> result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void copy(String v) => copySecret(context, ref, v);
    SecretField plain(String label, String value) =>
        SecretField(label: label, value: value, sensitive: false, onCopy: copy);
    List<Widget> secretData(Map<String, dynamic> data) => [
      for (final e in data.entries)
        SecretField(
          label: e.key,
          value: e.value is String ? e.value as String : jsonEncode(e.value),
          multiline: true,
          onCopy: copy,
        ),
    ];

    return AsyncValueView<SharingResult?>(
      value: result,
      empty: 'Results appear here.',
      data: (r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: switch (r!) {
              WrapResult(:final secret) => [
                SecretField(
                  label: 'Wrapping token',
                  value: secret.token,
                  onCopy: copy,
                ),
                plain('Accessor', secret.accessor),
                plain('TTL', formatDuration(secret.ttl)),
                plain('Expires', '${secret.expiresAt.toLocal()}'),
                const SizedBox(height: 8),
                _ShareActions(token: secret.token),
              ],
              UnwrapResult(:final secret) => [
                ...secretData(secret.data),
                if (secret.requestId.isNotEmpty)
                  plain('Request ID', secret.requestId),
                if (secret.leaseDuration > Duration.zero)
                  plain('Lease', formatDuration(secret.leaseDuration)),
                for (final w in secret.warnings) plain('Warning', w),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'The wrapping token is now spent and cannot be reused.',
                  ),
                ),
              ],
              CubbyholeReadResult(:final path, :final data) => [
                plain('Path', 'cubbyhole/$path'),
                ...secretData(data),
              ],
              CubbyholeChangedResult(:final message) => [Text(message)],
            },
          ),
        ),
      ),
    );
  }
}
