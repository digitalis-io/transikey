import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/domain/server_profile.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/vault_session.dart';
import 'session_provider.dart';

/// Switches to another server. A live session is ended first (after
/// confirmation), so nothing issued by one server is on screen, or sent,
/// while another one is active. Returns false when the user cancelled.
Future<bool> switchServerProfile(
  BuildContext context,
  WidgetRef ref,
  ServerProfile target,
) async {
  final session = ref.read(vaultSessionProvider);
  if (session is! SessionUnauthenticated) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Switch to ${target.name}?'),
        content: const Text(
          'You are signed out of the current server first. Credentials on '
          'screen are cleared; leases already issued keep running on the '
          'server until they expire.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out and switch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    await ref.read(vaultSessionProvider.notifier).logout();
  }
  await ref.read(settingsProvider.notifier).applyProfile(target.id);
  return true;
}
