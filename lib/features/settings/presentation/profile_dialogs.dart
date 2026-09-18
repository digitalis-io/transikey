import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/server_profile.dart';
import 'settings_provider.dart';

/// Colour dot used wherever a profile is shown.
class ProfileDot extends StatelessWidget {
  const ProfileDot(this.color, {super.key, this.size = 12});

  final int color;
  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.circle,
    size: size,
    color: color == 0 ? Theme.of(context).colorScheme.outline : Color(color),
  );
}

/// Asks for a name and a colour tag. With [existing] it edits that profile,
/// otherwise it saves the current server as a new one.
Future<void> showProfileDialog(
  BuildContext context,
  WidgetRef ref, {
  ServerProfile? existing,
}) async {
  final settings = ref.read(settingsProvider).value;
  final suggested =
      existing?.name ?? Uri.tryParse(settings?.vaultAddr ?? '')?.host ?? '';
  final name = TextEditingController(text: suggested);
  var color = existing?.color ?? 0;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Save server profile' : 'Edit profile'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'prod, staging, customer-x…',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Colour tag'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in profileColors.entries)
                    ChoiceChip(
                      avatar: ProfileDot(entry.value),
                      label: Text(entry.key),
                      selected: color == entry.value,
                      onSelected: (_) => setState(() => color = entry.value),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  final chosen = name.text.trim();
  name.dispose();
  if (confirmed != true || chosen.isEmpty) return;
  final notifier = ref.read(settingsProvider.notifier);
  if (existing == null) {
    await notifier.saveAsProfile(chosen, color: color);
  } else {
    await notifier.updateProfile(existing.id, name: chosen, color: color);
  }
}
