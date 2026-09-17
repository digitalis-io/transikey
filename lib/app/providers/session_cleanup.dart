import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/vault_session.dart';
import '../../features/auth/presentation/session_provider.dart';
import '../../features/database/presentation/database_provider.dart';
import '../../features/leases/presentation/leases_provider.dart';
import '../../features/sharing/presentation/sharing_provider.dart';
import '../../features/ssh/presentation/ssh_provider.dart';

/// Drops every secret held in provider state as soon as the session is
/// locked or ended.
final sessionCleanupProvider = Provider<void>((ref) {
  ref.listen<SessionState>(vaultSessionProvider, (previous, next) {
    if (next is SessionAuthenticated) return;
    ref.invalidate(databaseCredentialsProvider);
    ref.invalidate(databaseRolesProvider);
    ref.invalidate(sshCredentialsProvider);
    ref.invalidate(sshRolesProvider);
    ref.invalidate(secretSharingProvider);
    ref.invalidate(cubbyholeKeysProvider);
    if (next is SessionUnauthenticated) ref.invalidate(leasesProvider);
  });
});
