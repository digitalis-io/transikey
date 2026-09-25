import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/kubernetes_credentials.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/resizable_split.dart';
import '../../../core/widgets/role_picker.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_provider.dart';
import 'kubernetes_credentials_card.dart';
import 'kubernetes_provider.dart';
import 'namespace_field.dart';

class KubernetesScreen extends ConsumerStatefulWidget {
  const KubernetesScreen({super.key});

  @override
  ConsumerState<KubernetesScreen> createState() => _KubernetesScreenState();
}

class _KubernetesScreenState extends ConsumerState<KubernetesScreen> {
  final _namespace = TextEditingController();
  final _namespaceFocus = FocusNode();
  final _ttl = TextEditingController();
  KubernetesRoleRef? _selected;
  bool _clusterRoleBinding = false;

  /// The namespace the app filled in, so a role switch replaces it but
  /// never what the user typed.
  String? _suggested;

  /// Fills the namespace once the selected role is read. Opened with
  /// fireImmediately: a role picked again may already be loaded.
  ProviderSubscription<AsyncValue<KubernetesRoleInfo?>>? _roleInfo;

  @override
  void initState() {
    super.initState();
    // A pick from the list changes the text without an onChanged call.
    _namespace.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _roleInfo?.close();
    _namespaceFocus.dispose();
    _namespace.dispose();
    _ttl.dispose();
    super.dispose();
  }

  void _pick(String mount, String role) {
    final picked = (mount: mount, role: role);
    if (picked == _selected) return;
    // Credentials of the previous role must not linger on screen.
    ref.read(kubernetesCredentialsProvider.notifier).clear();
    if (_namespace.text == _suggested) _namespace.clear();
    _suggested = null;
    setState(() => _selected = picked);
    // Known right away, also when the role cannot be read.
    _suggest(null);
    _roleInfo?.close();
    _roleInfo = ref.listenManual(
      kubernetesRoleInfoProvider(picked),
      (_, next) => _suggest(next.value),
      fireImmediately: true,
    );
  }

  List<String> _recent(KubernetesRoleRef? role) => role == null
      ? const []
      : (ref.read(settingsProvider).value ?? const AppSettings())
                .kubernetesRecentNamespaces['${role.mount}/${role.role}'] ??
            const [];

  /// The last namespace used with the role, else the first it allows.
  void _suggest(KubernetesRoleInfo? info) {
    final namespace =
        _recent(_selected).firstOrNull ?? info?.suggestedNamespace;
    if (namespace == null || _namespace.text.isNotEmpty) return;
    _namespace.text = namespace;
    _suggested = namespace;
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(kubernetesRolesProvider);
    final credentials = ref.watch(kubernetesCredentialsProvider);
    final selected = _selected;
    final info = selected == null
        ? null
        : ref.watch(kubernetesRoleInfoProvider(selected));
    final allowed = info?.value?.allowedNamespaces ?? const [];
    final choices = info?.value?.namespaceChoices ?? const <String>[];
    // Watched so a namespace used a moment ago shows up in the list.
    ref.watch(
      settingsProvider.select((s) => s.value?.kubernetesRecentNamespaces),
    );
    final recent = _recent(selected);
    final severalMounts = (groups.value?.length ?? 0) > 1;
    final label = selected == null
        ? null
        : severalMounts
        ? '${selected.mount}/${selected.role}'
        : selected.role;

    return FeaturePage(
      title: 'Kubernetes Access',
      scrollable: false,
      child: ResizableSplit(
        left: RolePicker(
          groups: groups,
          selected: selected == null ? null : (selected.mount, selected.role),
          onSelected: _pick,
          onRefresh: () {
            ref.invalidate(kubernetesMountsProvider);
            ref.invalidate(kubernetesRolesProvider);
            // Policy may have changed: read the role again.
            ref.invalidate(kubernetesRoleInfoProvider);
          },
        ),
        right: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: NamespaceField(
                      controller: _namespace,
                      focusNode: _namespaceFocus,
                      recent: recent,
                      allowed: choices,
                      helperText: namespaceHelp(
                        allowed: allowed,
                        choices: choices,
                        selector: info?.value?.namespaceSelector ?? '',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _ttl,
                      decoration: const InputDecoration(
                        labelText: 'TTL (optional)',
                        hintText: 'e.g. 30m',
                        // Kubernetes refuses shorter service account tokens.
                        helperText: 'At least 10m',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: CheckboxListTile(
                      value: _clusterRoleBinding,
                      onChanged: (v) =>
                          setState(() => _clusterRoleBinding = v ?? false),
                      title: const Text('Cluster-wide binding'),
                      subtitle: const Text('ClusterRole roles only'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    selected == null ||
                        _namespace.text.trim().isEmpty ||
                        credentials.isLoading
                    ? null
                    : () => ref
                          .read(kubernetesCredentialsProvider.notifier)
                          .request((
                            role: selected,
                            namespace: _namespace.text.trim(),
                            ttl: _ttl.text.trim(),
                            clusterRoleBinding: _clusterRoleBinding,
                          )),
                icon: const Icon(Icons.vpn_key),
                label: Text(
                  label == null ? 'Request token' : 'Request token for $label',
                ),
              ),
              if (selected == null || _namespace.text.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    selected == null
                        ? 'Pick a role in the list on the left first.'
                        : 'Enter the namespace for the service account.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              AsyncValueView<KubernetesCredentials?>(
                value: credentials,
                empty: 'Request a token to see it here.',
                data: (c) => KubernetesCredentialsCard(c!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
