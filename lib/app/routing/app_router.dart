import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/vault_session.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/session_provider.dart';
import '../../features/database/presentation/database_screen.dart';
import '../../features/leases/presentation/leases_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sharing/presentation/sharing_screen.dart';
import '../../features/ssh/presentation/ssh_screen.dart';
import '../shell/app_shell.dart';

/// One sidebar entry. Order defines the Ctrl/Cmd+1..6 shortcuts.
class AppDestination {
  const AppDestination(this.path, this.label, this.icon, {this.public = false});

  final String path;
  final String label;
  final IconData icon;

  /// Reachable without an authenticated session.
  final bool public;
}

const appDestinations = [
  AppDestination('/auth', 'Authentication', Icons.key, public: true),
  AppDestination('/database', 'Database Credentials', Icons.storage),
  AppDestination('/ssh', 'SSH Access', Icons.terminal),
  // Public: a share link recipient can unwrap without a session.
  AppDestination('/sharing', 'Secret Sharing', Icons.ios_share, public: true),
  AppDestination('/leases', 'Lease Management', Icons.timer_outlined),
  AppDestination('/settings', 'Settings', Icons.settings, public: true),
];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(vaultSessionProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/auth',
    refreshListenable: refresh,
    redirect: (context, state) {
      // A locked session keeps its route; the shell covers it with the lock
      // screen and the user resumes where they were.
      final authenticated =
          ref.read(vaultSessionProvider) is! SessionUnauthenticated;
      final destination = appDestinations.firstWhere(
        (d) => state.matchedLocation.startsWith(d.path),
        orElse: () => appDestinations.first,
      );
      return authenticated || destination.public ? null : '/auth';
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          for (final (path, screen) in <(String, Widget)>[
            ('/auth', const AuthScreen()),
            ('/database', const DatabaseScreen()),
            ('/ssh', const SshScreen()),
            ('/sharing', const SharingScreen()),
            ('/leases', const LeasesScreen()),
            ('/settings', const SettingsScreen()),
          ])
            GoRoute(
              path: path,
              pageBuilder: (context, state) =>
                  NoTransitionPage(key: state.pageKey, child: screen),
            ),
        ],
      ),
    ],
  );
});
