import 'package:freezed_annotation/freezed_annotation.dart';

import 'lease_info.dart';

part 'database_credentials.freezed.dart';

/// Dynamic database credentials issued by a database secrets engine role.
@freezed
abstract class DatabaseCredentials with _$DatabaseCredentials {
  const DatabaseCredentials._();

  const factory DatabaseCredentials({
    required String mount,
    required String role,
    required String username,
    required String password,
    required LeaseInfo lease,
  }) = _DatabaseCredentials;

  /// Identifies the role across mounts.
  String get key => '$mount/$role';

  @override
  String toString() =>
      'DatabaseCredentials(mount: $mount, role: $role, username: ***, password: ***)';
}
