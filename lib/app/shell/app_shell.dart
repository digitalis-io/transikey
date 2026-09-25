import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/auth/domain/vault_session.dart';
import '../../features/auth/presentation/lock_screen.dart';
import '../../features/auth/presentation/session_provider.dart';
import '../../features/settings/presentation/settings_provider.dart';
import '../routing/app_router.dart';
import 'status_bar.dart';

/// Desktop navigation shell: collapsible sidebar, status bar, keyboard
/// shortcuts, lock overlay and privacy blur.
///
/// The shell holds no window-global state, so a second window can host its
/// own `ProviderScope` + shell when multi-window support lands.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WindowListener {
  bool _expanded = true;
  bool _windowFocused = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowBlur() => setState(() => _windowFocused = false);

  @override
  void onWindowFocus() => setState(() => _windowFocused = true);

  int get _selectedIndex {
    final index = appDestinations.indexWhere(
      (d) => widget.location.startsWith(d.path),
    );
    return index < 0 ? 0 : index;
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(bool authenticated) {
    final mac = Theme.of(context).platform == TargetPlatform.macOS;
    SingleActivator key(LogicalKeyboardKey k) =>
        SingleActivator(k, meta: mac, control: !mac);
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
    ];
    return {
      for (var i = 0; i < appDestinations.length; i++)
        key(digits[i]): () => context.go(appDestinations[i].path),
      key(LogicalKeyboardKey.keyB): () =>
          setState(() => _expanded = !_expanded),
      key(LogicalKeyboardKey.comma): () => context.go('/settings'),
      if (authenticated)
        key(LogicalKeyboardKey.keyL): ref
            .read(vaultSessionProvider.notifier)
            .lock,
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(vaultSessionProvider);
    final authenticated = session is SessionAuthenticated;
    final blurOnFocusLoss = ref.watch(
      settingsProvider.select((s) => s.value?.blurOnFocusLoss ?? true),
    );
    final scheme = Theme.of(context).colorScheme;

    final content = Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: _expanded,
            minExtendedWidth: 230,
            backgroundColor: scheme.surfaceContainerLow,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => context.go(appDestinations[i].path),
            leading: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/branding/transikey_mark.png',
                          width: 44,
                          filterQuality: FilterQuality.medium,
                        ),
                        if (_expanded) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Transikey',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      tooltip: _expanded
                          ? 'Collapse sidebar'
                          : 'Expand sidebar',
                      icon: Icon(_expanded ? Icons.menu_open : Icons.menu),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
                  ],
                ),
              ),
            ),
            destinations: [
              for (final d in appDestinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                  disabled: !authenticated && !d.public,
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                const StatusBar(),
                const Divider(height: 1),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );

    final obscure = authenticated && blurOnFocusLoss && !_windowFocused;

    return CallbackShortcuts(
      bindings: _shortcuts(authenticated),
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            content,
            if (obscure)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: ColoredBox(
                    color: scheme.surface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            if (session is SessionLocked)
              Positioned.fill(child: LockScreen(session: session.session)),
          ],
        ),
      ),
    );
  }
}
