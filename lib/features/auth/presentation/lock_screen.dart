import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/vault_session.dart';
import 'session_provider.dart';

final _biometricsUsableProvider = FutureProvider.autoDispose<bool>((ref) async {
  final enabled = ref.watch(
    settingsProvider.select((s) => s.value?.biometricUnlock ?? false),
  );
  return enabled && await ref.watch(biometricAuthProvider).isAvailable();
});

/// Full-window overlay shown while the session is locked. Blurs whatever is
/// underneath.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.session});

  final VaultSession session;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _unlock() async {
    setState(() => _busy = true);
    final ok = await ref.read(vaultSessionProvider.notifier).unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? null : 'Unlock failed. Try again or sign in again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final biometrics = ref.watch(_biometricsUsableProvider).value ?? false;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: ColoredBox(
        color: theme.colorScheme.surface.withValues(alpha: 0.75),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/branding/transikey_mark.png', width: 120),
                const SizedBox(height: 8),
                Icon(Icons.lock, size: 32, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Session locked', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Signed in as ${widget.session.displayName}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (biometrics)
                  FilledButton.icon(
                    onPressed: _busy ? null : _unlock,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock'),
                  )
                else
                  Text(
                    'Biometric unlock is off or unavailable. Sign in again to continue.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => ref.read(vaultSessionProvider.notifier).logout(),
                  child: const Text('Sign in again'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
