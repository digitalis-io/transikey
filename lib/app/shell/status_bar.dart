import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/health_status.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/duration_format.dart';
import '../../core/widgets/async_value_view.dart';
import '../../features/auth/domain/vault_session.dart';
import '../../features/auth/presentation/session_provider.dart';
import '../../features/leases/presentation/leases_provider.dart';
import '../../features/settings/presentation/settings_provider.dart';

/// Connection, seal, version and session indicators.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(vaultConnectionProvider);
    final session = ref.watch(vaultSessionProvider);
    final address = ref.watch(
      settingsProvider.select((s) => s.value?.vaultAddr ?? ''),
    );
    final tlsVerify = ref.watch(
      settingsProvider.select((s) => s.value?.tlsVerify ?? true),
    );
    final plainHttp = address.trim().toLowerCase().startsWith('http://');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ..._connection(health, address),
          if (plainHttp) ...[
            const SizedBox(width: 12),
            const _Chip(
              StatusColors.expired,
              'Unencrypted HTTP',
              tooltip: 'Tokens and secrets travel in clear text. Use https.',
            ),
          ] else if (!tlsVerify) ...[
            const SizedBox(width: 12),
            const _Chip(
              StatusColors.expiringSoon,
              'TLS verification off',
              tooltip: 'The server certificate is not checked.',
            ),
          ],
          const Spacer(),
          _SessionIndicator(session: session),
          if (session is SessionAuthenticated)
            IconButton(
              tooltip: 'Lock session',
              icon: const Icon(Icons.lock_outline),
              onPressed: ref.read(vaultSessionProvider.notifier).lock,
            ),
        ],
      ),
    );
  }

  List<Widget> _connection(AsyncValue<HealthStatus?> health, String address) {
    if (health.isLoading && !health.hasValue) {
      return const [_Chip(StatusColors.unknown, 'Connecting…')];
    }
    if (health.hasError) {
      return [
        _Chip(
          StatusColors.expired,
          'Disconnected',
          tooltip: errorMessage(health.error!),
        ),
      ];
    }
    final status = health.value;
    if (status == null) {
      return const [_Chip(StatusColors.unknown, 'No server configured')];
    }
    return [
      _Chip(StatusColors.active, 'Connected', tooltip: address),
      const SizedBox(width: 8),
      status.sealed
          ? const _Chip(StatusColors.expired, 'Sealed')
          : const _Chip(StatusColors.active, 'Unsealed'),
      if (status.standby) ...[
        const SizedBox(width: 8),
        const _Chip(StatusColors.expiringSoon, 'Standby'),
      ],
      const SizedBox(width: 12),
      Text('v${status.version}'),
      if (status.clusterName.isNotEmpty) ...[
        const SizedBox(width: 12),
        Text(status.clusterName),
      ],
    ];
  }
}

class _SessionIndicator extends ConsumerWidget {
  const _SessionIndicator({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (session) {
      case SessionUnauthenticated():
        return const _Chip(StatusColors.unknown, 'Signed out');
      case SessionLocked():
        return const _Chip(StatusColors.expiringSoon, 'Locked');
      case SessionAuthenticated(:final session):
        final now = ref.watch(clockProvider).value ?? DateTime.now();
        final left = session.remaining(now);
        final label = left == null
            ? session.displayName
            : '${session.displayName} · ${formatDuration(left)}';
        final color = left != null && left < const Duration(minutes: 5)
            ? StatusColors.expiringSoon
            : StatusColors.active;
        return _Chip(color, label, tooltip: 'Token time to live');
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.color, this.label, {this.tooltip});

  final Color color;
  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
    return tooltip == null || tooltip!.isEmpty
        ? chip
        : Tooltip(message: tooltip, child: chip);
  }
}
