import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../data/vault_sharing_repository.dart';
import '../domain/sharing_repository.dart';

final sharingRepositoryProvider = Provider<SharingRepository>(
  (ref) => VaultSharingRepository(ref.watch(apiClientProvider)),
);

final cubbyholeKeysProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(sharingRepositoryProvider).cubbyholeList(),
);

/// Result of the last sharing operation. `AsyncData(null)` is the empty state.
final secretSharingProvider =
    AsyncNotifierProvider<SecretSharingNotifier, SharingResult?>(
      SecretSharingNotifier.new,
    );

class SecretSharingNotifier extends AsyncNotifier<SharingResult?> {
  int _generation = 0;

  SharingRepository get _repository => ref.read(sharingRepositoryProvider);

  @override
  Future<SharingResult?> build() async => null;

  Future<void> wrap(Map<String, dynamic> payload, Duration ttl) =>
      _run(() async => WrapResult(await _repository.wrap(payload, ttl)));

  Future<void> unwrap(String token) =>
      _run(() async => UnwrapResult(await _repository.unwrap(token)));

  Future<void> cubbyholeStore(String path, Map<String, dynamic> data) =>
      _run(() async {
        await _repository.cubbyholeStore(path, data);
        ref.invalidate(cubbyholeKeysProvider);
        return CubbyholeChangedResult('Stored cubbyhole/$path');
      });

  Future<void> cubbyholeRetrieve(String path) => _run(
    () async =>
        CubbyholeReadResult(path, await _repository.cubbyholeRetrieve(path)),
  );

  Future<void> cubbyholeDelete(String path) => _run(() async {
    await _repository.cubbyholeDelete(path);
    ref.invalidate(cubbyholeKeysProvider);
    return CubbyholeChangedResult('Deleted cubbyhole/$path');
  });

  void clear() {
    _generation++;
    state = const AsyncData(null);
  }

  /// Results of a request superseded by [clear] or a newer request are
  /// dropped, so they never show up under another tab.
  Future<void> _run(Future<SharingResult> Function() body) async {
    final generation = ++_generation;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(body);
    if (ref.mounted && generation == _generation) state = result;
  }
}
