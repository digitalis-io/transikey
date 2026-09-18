import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/errors/vault_exception.dart';
import '../../../core/models/database_credentials.dart';
import '../../../core/utils/db_target_detection.dart';
import '../../../core/widgets/role_picker.dart';
import '../../auth/presentation/session_provider.dart';
import '../../leases/presentation/leases_provider.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_provider.dart';
import '../data/vault_database_repository.dart';
import '../domain/database_repository.dart';

/// A role on one database mount.
typedef DatabaseRoleRef = ({String mount, String role});

final databaseRepositoryProvider = Provider<DatabaseRepository>(
  (ref) => VaultDatabaseRepository(ref.watch(apiClientProvider)),
);

/// Database mounts: what the server reveals, else the mounts from settings.
final databaseMountsProvider = FutureProvider<List<String>>((ref) async {
  if (!ref.watch(sessionActiveProvider)) return const [];
  final configured = ref.watch(
    settingsProvider.select(
      (s) => (s.value ?? const AppSettings()).databaseMountList,
    ),
  );
  try {
    final found = await ref.watch(databaseRepositoryProvider).discoverMounts();
    return found.isEmpty ? configured : found;
  } on VaultException {
    return configured;
  }
});

/// Roles of every mount. A mount that cannot be listed carries its error
/// instead of failing the others.
final databaseRolesProvider = FutureProvider<List<RoleGroup>>((ref) async {
  final mounts = await ref.watch(databaseMountsProvider.future);
  final repository = ref.watch(databaseRepositoryProvider);
  Future<RoleGroup> list(String mount) async {
    try {
      return RoleGroup(name: mount, roles: await repository.listRoles(mount));
    } on VaultException catch (e) {
      return RoleGroup(name: mount, error: e.message);
    }
  }

  return Future.wait(mounts.map(list));
});

/// Engine and address behind a role, or null when the token may not read
/// them. Null means: ask the user.
final detectedDatabaseProvider = FutureProvider.autoDispose
    .family<DetectedDatabase?, DatabaseRoleRef>((ref, role) async {
      if (!ref.watch(sessionActiveProvider)) return null;
      try {
        return await ref
            .watch(databaseRepositoryProvider)
            .describeRole(role.mount, role.role);
      } on VaultException {
        return null;
      }
    });

/// Most recently issued credentials. `AsyncData(null)` is the empty state.
final databaseCredentialsProvider =
    AsyncNotifierProvider<DatabaseCredentialsNotifier, DatabaseCredentials?>(
      DatabaseCredentialsNotifier.new,
    );

class DatabaseCredentialsNotifier extends AsyncNotifier<DatabaseCredentials?> {
  // A cleared or repeated request must not resurface a stale answer.
  int _generation = 0;

  @override
  Future<DatabaseCredentials?> build() async => null;

  Future<void> request(DatabaseRoleRef role) async {
    final generation = ++_generation;
    state = const AsyncLoading();
    final result = await AsyncValue.guard<DatabaseCredentials?>(() async {
      final creds = await ref
          .read(databaseRepositoryProvider)
          .requestCredentials(role.mount, role.role);
      ref.read(leasesProvider.notifier).track(creds.lease, creds.key);
      return creds;
    });
    if (ref.mounted && generation == _generation) state = result;
  }

  void clear() {
    _generation++;
    state = const AsyncData(null);
  }
}
