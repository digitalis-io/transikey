import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/clipboard_actions.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/secret_field.dart';
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

class _SharingScreenState extends ConsumerState<SharingScreen> {
  final _payload = TextEditingController();
  final _wrappingToken = TextEditingController();
  final _cubbyPath = TextEditingController();
  final _cubbyData = TextEditingController();
  Duration _ttl = _ttlChoices.values.elementAt(1);

  @override
  void dispose() {
    for (final c in [_payload, _wrappingToken, _cubbyPath, _cubbyData]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(secretSharingProvider);
    final notifier = ref.read(secretSharingProvider.notifier);
    final busy = result.isLoading;

    return DefaultTabController(
      length: 3,
      child: FeaturePage(
        title: 'Secret Sharing',
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              onTap: (_) => notifier.clear(),
              tabs: const [
                Tab(text: 'Wrap'),
                Tab(text: 'Unwrap'),
                Tab(text: 'Cubbyhole'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _tab([
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
                    _button('Wrap secret', Icons.lock, busy, () async {
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
                    _button('Unwrap', Icons.lock_open, busy, () async {
                      await notifier.unwrap(_wrappingToken.text);
                      if (!mounted) return;
                      _wrappingToken.clear();
                    }),
                    _ResultView(result),
                  ]),
                  _tab([
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
                          onPressed: busy
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
                          onPressed: busy
                              ? null
                              : () =>
                                    notifier.cubbyholeRetrieve(_cubbyPath.text),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Retrieve'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => notifier.cubbyholeDelete(_cubbyPath.text),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
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
