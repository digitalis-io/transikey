import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_profile.freezed.dart';
part 'server_profile.g.dart';

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
    @Default('psql') String databaseClient,
    @Default('127.0.0.1') String databaseHost,
    @Default(5432) int databasePort,
    @Default('app') String databaseName,
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
