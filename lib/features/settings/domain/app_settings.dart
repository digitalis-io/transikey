import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/vault_connection_config.dart';

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
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  bool get isConfigured => vaultAddr.trim().isNotEmpty;

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
    ),
  );

  static String _mount(String value, String fallback) {
    final clean = value.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    return clean.isEmpty ? fallback : clean;
  }
}
