import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/dio_vault_api_client.dart';
import '../../core/api/vault_api_client.dart';
import '../../core/api/vault_connection_config.dart';
import '../../core/security/biometric_auth.dart';
import '../../core/security/clipboard_guard.dart';
import '../../core/security/screen_protection.dart';
import '../../core/security/secret_store.dart';
import '../../core/utils/app_logger.dart';
import '../../features/settings/domain/app_settings.dart';
import '../../features/settings/presentation/settings_provider.dart';

final loggerProvider = Provider<AppLogger>((ref) => AppLogger());

final secretStoreProvider = Provider<SecretStore>(
  (ref) => FlutterSecureSecretStore(),
);

/// Opens a URL in the system browser (OIDC login).
final browserLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => LocalBiometricAuth(),
);

final screenProtectionProvider = Provider<ScreenProtection>(
  (ref) => const NoopScreenProtection(),
);

/// In-memory home of the session token. Never rebuilt.
final tokenHolderProvider = Provider<TokenHolder>((ref) => TokenHolder());

final clipboardGuardProvider = Provider<ClipboardGuard>((ref) {
  final guard = ClipboardGuard(
    timeout: () =>
        ref.read(settingsProvider).value?.clipboardTimeout ??
        const Duration(seconds: 30),
  );
  ref.onDispose(guard.dispose);
  return guard;
});

/// Builds a client for arbitrary settings: the connection test and share
/// links that point at another server. Such a client gets its own empty
/// [TokenHolder], so the session token can never reach a foreign address.
final apiClientFactoryProvider = Provider<VaultApiClient Function(AppSettings)>(
  (ref) {
    return (settings) {
      final config = settings.toConnectionConfig();
      return DioVaultApiClient(
        dio: buildVaultDio(
          config: config,
          tokenHolder: TokenHolder(),
          logger: ref.read(loggerProvider),
        ),
        config: config,
      );
    };
  },
);

/// Client for the saved connection settings. Rebuilt when they change.
final apiClientProvider = Provider<VaultApiClient>((ref) {
  final config = ref.watch(
    settingsProvider.select(
      (s) => (s.value ?? const AppSettings()).toConnectionConfig(),
    ),
  );
  final dio = buildVaultDio(
    config: config,
    tokenHolder: ref.watch(tokenHolderProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(dio.close);
  return DioVaultApiClient(dio: dio, config: config);
});
