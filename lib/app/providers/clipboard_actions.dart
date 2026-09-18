import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/settings_provider.dart';
import 'core_providers.dart';

/// Copies [value] through the clipboard guard and tells the user when the
/// clipboard will be cleared.
Future<void> copySecret(
  BuildContext context,
  WidgetRef ref,
  String value,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(clipboardGuardProvider).copy(value);
  final seconds = ref.read(settingsProvider).value?.clipboardClearSeconds ?? 30;
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(
        seconds > 0
            ? 'Copied. Clipboard clears in ${seconds}s.'
            : 'Copied. Clipboard auto-clear is off.',
      ),
    ),
  );
}
