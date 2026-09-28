import 'package:freezed_annotation/freezed_annotation.dart';

import 'lease_info.dart';

part 'kubernetes_credentials.freezed.dart';

/// Service account token issued by a Kubernetes secrets engine role.
@freezed
abstract class KubernetesCredentials with _$KubernetesCredentials {
  const KubernetesCredentials._();

  const factory KubernetesCredentials({
    required String mount,
    required String role,
    required String serviceAccountToken,
    required String serviceAccountName,
    required String serviceAccountNamespace,
    required LeaseInfo lease,
  }) = _KubernetesCredentials;

  /// Identifies the role across mounts.
  String get key => '$mount/$role';

  @override
  String toString() =>
      'KubernetesCredentials(mount: $mount, role: $role, '
      'serviceAccountName: $serviceAccountName, '
      'serviceAccountNamespace: $serviceAccountNamespace, '
      'serviceAccountToken: ***)';
}

/// Tokens of one role, one per namespace: the engine binds a service
/// account to a single namespace, so several namespaces take several
/// requests. [failures] maps each namespace the server refused to why.
class KubernetesTokenSet {
  const KubernetesTokenSet({
    required this.mount,
    required this.role,
    required this.tokens,
    this.failures = const {},
  });

  final String mount;
  final String role;
  final List<KubernetesCredentials> tokens;
  final Map<String, String> failures;

  /// Identifies the role across mounts.
  String get key => '$mount/$role';

  @override
  String toString() =>
      'KubernetesTokenSet(mount: $mount, role: $role, tokens: $tokens, '
      'failures: $failures)';
}

/// What a Kubernetes role allows, read from `<mount>/roles/<role>`.
class KubernetesRoleInfo {
  const KubernetesRoleInfo({
    this.allowedNamespaces = const [],
    this.roleType = '',
    this.namespaceSelector = '',
  });

  /// `allowed_kubernetes_namespaces`. May contain `*`.
  final List<String> allowedNamespaces;

  /// `kubernetes_role_type`: `Role` or `ClusterRole`.
  final String roleType;

  /// `allowed_kubernetes_namespace_selector`: a label selector as JSON or
  /// YAML. Namespaces carrying those labels are allowed too. Only the
  /// cluster knows which they are.
  final String namespaceSelector;

  /// Allowed namespaces the user can pick from: named ones, no wildcard.
  List<String> get namespaceChoices => [
    for (final n in allowedNamespaces)
      if (n.trim().isNotEmpty && n.trim() != '*') n.trim(),
  ];

  /// First namespace that names one namespace, not a wildcard.
  String? get suggestedNamespace => namespaceChoices.firstOrNull;
}
