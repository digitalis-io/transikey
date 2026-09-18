import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../auth/presentation/session_provider.dart';
import '../../leases/presentation/leases_provider.dart';
import '../data/vault_ssh_repository.dart';
import '../domain/ssh_repository.dart';

final sshRepositoryProvider = Provider<SshRepository>(
  (ref) => VaultSshRepository(ref.watch(apiClientProvider)),
);

final sshRolesProvider = FutureProvider<List<String>>((ref) async {
  if (!ref.watch(sessionActiveProvider)) return const [];
  return ref.watch(sshRepositoryProvider).listRoles();
});

/// Result of the last SSH operation. `AsyncData(null)` is the empty state.
final sshCredentialsProvider =
    AsyncNotifierProvider<SshCredentialsNotifier, SshResult?>(
      SshCredentialsNotifier.new,
    );

class SshCredentialsNotifier extends AsyncNotifier<SshResult?> {
  int _generation = 0;

  @override
  Future<SshResult?> build() async => null;

  Future<void> requestOtp(
    String role, {
    required String ip,
    String? username,
  }) => _run(() async {
    final creds = await ref
        .read(sshRepositoryProvider)
        .requestOtp(role, ip: ip, username: username);
    ref.read(leasesProvider.notifier).track(creds.lease, 'ssh/$role');
    return SshOtpResult(creds);
  });

  Future<void> sign(
    String role,
    String publicKey, {
    String? validPrincipals,
    Duration? ttl,
  }) => _run(
    () async => SshSignedResult(
      await ref
          .read(sshRepositoryProvider)
          .signPublicKey(
            role,
            publicKey,
            validPrincipals: validPrincipals,
            ttl: ttl,
          ),
    ),
  );

  Future<void> requestAttemptToken(Map<String, dynamic> params) => _run(
    () async => SshAttemptTokenResult(
      await ref.read(sshRepositoryProvider).requestAttemptToken(params),
      DateTime.now(),
    ),
  );

  void clear() {
    _generation++;
    state = const AsyncData(null);
  }

  /// Results of a request superseded by [clear] or a newer request are
  /// dropped, so they never show up under another tab.
  Future<void> _run(Future<SshResult> Function() body) async {
    final generation = ++_generation;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(body);
    if (ref.mounted && generation == _generation) state = result;
  }
}
