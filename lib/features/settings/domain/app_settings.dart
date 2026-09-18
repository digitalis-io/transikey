import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/vault_connection_config.dart';
import 'server_profile.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

enum AppThemeMode { system, light, dark }

/// User preferences. Persisted as JSON in the OS keystore because the custom
/// CA and server address are environment details worth protecting.
@freezed
abstract class AppSettings with _$AppSettings {
  const AppSettings._();

  const factory AppSettings({
    @Default('') String vaultAddr,
    @Default('') String namespace,
    @Default(true) bool tlsVerify,
    String? caCertPem,
    String? caCertName,
    @Default(AppThemeMode.system) AppThemeMode themeMode,
    @Default(300) int inactivityTimeoutSeconds,
    @Default(30) int clipboardClearSeconds,
    @Default(false) bool biometricUnlock,
    @Default(true) bool blurOnFocusLoss,
    @Default('database') String databaseMount,
    @Default('ssh') String sshMount,
    @Default('userpass') String userpassMount,
    @Default('approle') String approleMount,
    @Default('ldap') String ldapMount,
    @Default('oidc') String oidcMount,
    @Default('psql') String databaseClient,
    @Default('127.0.0.1') String databaseHost,
    @Default(5432) int databasePort,
    @Default('app') String databaseName,
    @Default('ubuntu') String sshUser,
    @Default('127.0.0.1') String sshHost,
    @Default(2222) int sshPort,
    @Default('~/.ssh/id_ed25519') String sshKeyPath,

    /// Remembered servers. The server scoped fields above always describe
    /// the active one and are written back to it on every save.
    @Default([]) List<ServerProfile> profiles,
    String? activeProfileId,
    @Default('') String lastAuthMethod,
    @Default('') String lastUsername,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  bool get isConfigured => vaultAddr.trim().isNotEmpty;

  ServerProfile? get activeProfile =>
      profiles.where((p) => p.id == activeProfileId).firstOrNull;

  /// Snapshot of the server scoped fields as a profile.
  ServerProfile toProfile({
    required String id,
    required String name,
    int color = 0,
  }) => ServerProfile(
    id: id,
    name: name,
    color: color,
    vaultAddr: vaultAddr,
    namespace: namespace,
    tlsVerify: tlsVerify,
    caCertPem: caCertPem,
    caCertName: caCertName,
    databaseMount: databaseMount,
    sshMount: sshMount,
    userpassMount: userpassMount,
    approleMount: approleMount,
    ldapMount: ldapMount,
    oidcMount: oidcMount,
    databaseClient: databaseClient,
    databaseHost: databaseHost,
    databasePort: databasePort,
    databaseName: databaseName,
    sshUser: sshUser,
    sshHost: sshHost,
    sshPort: sshPort,
    sshKeyPath: sshKeyPath,
    lastAuthMethod: lastAuthMethod,
    lastUsername: lastUsername,
  );

  /// Makes [p] the active server: its fields replace the server scoped ones.
  AppSettings withProfile(ServerProfile p) => copyWith(
    activeProfileId: p.id,
    vaultAddr: p.vaultAddr,
    namespace: p.namespace,
    tlsVerify: p.tlsVerify,
    caCertPem: p.caCertPem,
    caCertName: p.caCertName,
    databaseMount: p.databaseMount,
    sshMount: p.sshMount,
    userpassMount: p.userpassMount,
    approleMount: p.approleMount,
    ldapMount: p.ldapMount,
    oidcMount: p.oidcMount,
    databaseClient: p.databaseClient,
    databaseHost: p.databaseHost,
    databasePort: p.databasePort,
    databaseName: p.databaseName,
    sshUser: p.sshUser,
    sshHost: p.sshHost,
    sshPort: p.sshPort,
    sshKeyPath: p.sshKeyPath,
    lastAuthMethod: p.lastAuthMethod,
    lastUsername: p.lastUsername,
  );

  /// Writes the current server scoped fields back into the active profile.
  AppSettings syncActiveProfile() {
    final active = activeProfile;
    if (active == null) return this;
    final updated = toProfile(
      id: active.id,
      name: active.name,
      color: active.color,
    );
    return copyWith(
      profiles: [for (final p in profiles) p.id == active.id ? updated : p],
    );
  }

  Duration get inactivityTimeout => Duration(seconds: inactivityTimeoutSeconds);
  Duration get clipboardTimeout => Duration(seconds: clipboardClearSeconds);

  VaultConnectionConfig toConnectionConfig() => VaultConnectionConfig(
    address: vaultAddr,
    namespace: namespace.trim(),
    tlsVerify: tlsVerify,
    caCertPem: caCertPem,
    mounts: VaultMounts(
      database: _mount(databaseMount, 'database'),
      ssh: _mount(sshMount, 'ssh'),
      userpass: _mount(userpassMount, 'userpass'),
      approle: _mount(approleMount, 'approle'),
      ldap: _mount(ldapMount, 'ldap'),
      oidc: _mount(oidcMount, 'oidc'),
    ),
  );

  static String _mount(String value, String fallback) {
    final clean = value.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    return clean.isEmpty ? fallback : clean;
  }
}
