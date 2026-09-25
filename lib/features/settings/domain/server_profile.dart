import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_profile.freezed.dart';
part 'server_profile.g.dart';

/// Connect target remembered for one database mount or connection. Host,
/// port and name only: no credentials.
@freezed
abstract class SavedDbTarget with _$SavedDbTarget {
  const factory SavedDbTarget({
    @Default('psql') String client,
    @Default('') String host,
    @Default(0) int port,
    @Default('') String database,
  }) = _SavedDbTarget;

  factory SavedDbTarget.fromJson(Map<String, dynamic> json) =>
      _$SavedDbTargetFromJson(json);
}

/// Kubernetes API server remembered for one Kubernetes mount. Vault does
/// not return it. Address and CA file path only: no credentials.
@freezed
abstract class SavedKubeTarget with _$SavedKubeTarget {
  const factory SavedKubeTarget({
    @Default('') String server,
    @Default('') String caPath,
  }) = _SavedKubeTarget;

  factory SavedKubeTarget.fromJson(Map<String, dynamic> json) =>
      _$SavedKubeTargetFromJson(json);
}

/// Everything that belongs to one Vault / OpenBao server: how to reach it,
/// where its engines are mounted, and the connect targets used with it.
/// Holds no secrets. The last username is kept; passwords and tokens never.
@freezed
abstract class ServerProfile with _$ServerProfile {
  const factory ServerProfile({
    required String id,
    required String name,

    /// ARGB colour tag, 0 for none. Shown in the status bar so that prod
    /// never looks like dev.
    @Default(0) int color,
    @Default('') String vaultAddr,
    @Default('') String namespace,
    @Default(true) bool tlsVerify,
    String? caCertPem,
    String? caCertName,
    @Default('database') String databaseMount,
    @Default('ssh') String sshMount,
    @Default('userpass') String userpassMount,
    @Default('approle') String approleMount,
    @Default('ldap') String ldapMount,
    @Default('oidc') String oidcMount,
    @Default('kubernetes') String kubernetesMount,
    @Default('psql') String databaseClient,
    @Default('127.0.0.1') String databaseHost,
    @Default(5432) int databasePort,
    @Default('app') String databaseName,

    /// Connect targets keyed by `mount` or `mount/connection`. The four
    /// fields above are the default for a key that is not in here.
    @Default({}) Map<String, SavedDbTarget> databaseTargets,

    /// Kubernetes API servers keyed by mount.
    @Default({}) Map<String, SavedKubeTarget> kubernetesTargets,

    /// Namespaces used with each Kubernetes role, keyed `mount/role`, most
    /// recent first. Names only; offered again when the role cannot tell.
    @Default({}) Map<String, List<String>> kubernetesRecentNamespaces,
    @Default('ubuntu') String sshUser,
    @Default('127.0.0.1') String sshHost,
    @Default(2222) int sshPort,
    @Default('~/.ssh/id_ed25519') String sshKeyPath,
    @Default('') String lastAuthMethod,
    @Default('') String lastUsername,
  }) = _ServerProfile;

  factory ServerProfile.fromJson(Map<String, dynamic> json) =>
      _$ServerProfileFromJson(json);
}

/// Colour tags offered in the UI (ARGB). Zero means "no tag".
const profileColors = <String, int>{
  'None': 0,
  'Red': 0xFFCF222E,
  'Orange': 0xFFD4A72C,
  'Green': 0xFF2DA44E,
  'Blue': 0xFF1F6FEB,
  'Purple': 0xFF8250DF,
};
