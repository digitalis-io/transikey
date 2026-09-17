import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/models/database_credentials.dart';
import '../../leases/presentation/leases_provider.dart';
import '../data/vault_database_repository.dart';
import '../domain/database_repository.dart';

final databaseRepositoryProvider = Provider<DatabaseRepository>(
  (ref) => VaultDatabaseRepository(ref.watch(apiClientProvider)),
);

final databaseRolesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(databaseRepositoryProvider).listRoles(),
);

/// Most recently issued credentials. `AsyncData(null)` is the empty state.
final databaseCredentialsProvider =
    AsyncNotifierProvider<DatabaseCredentialsNotifier, DatabaseCredentials?>(
      DatabaseCredentialsNotifier.new,
    );

class DatabaseCredentialsNotifier extends AsyncNotifier<DatabaseCredentials?> {
  @override
  Future<DatabaseCredentials?> build() async => null;

  Future<void> request(String role) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final creds = await ref
          .read(databaseRepositoryProvider)
          .requestCredentials(role);
      ref.read(leasesProvider.notifier).track(creds.lease, 'database/$role');
      return creds;
    });
  }

  void clear() => state = const AsyncData(null);
}
