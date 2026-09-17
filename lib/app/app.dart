import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/idle_detector.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/session_provider.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/settings/presentation/settings_provider.dart';
import 'providers/session_cleanup.dart';
import 'routing/app_router.dart';

class TransikeyApp extends ConsumerWidget {
  const TransikeyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionCleanupProvider);
    final mode = ref.watch(
      settingsProvider.select((s) => s.value?.themeMode ?? AppThemeMode.system),
    );
    return IdleDetector(
      onActivity: () =>
          ref.read(vaultSessionProvider.notifier).registerActivity(),
      child: MaterialApp.router(
        title: 'Transikey',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: switch (mode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
