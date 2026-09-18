import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'async_value_view.dart';

/// Roles of one mount. [error] replaces the roles when the mount could not
/// be listed.
class RoleGroup {
  const RoleGroup({this.name = '', this.roles = const [], this.error});

  /// Mount path. Empty for a picker with a single, unnamed group.
  final String name;
  final List<String> roles;
  final String? error;
}

/// Role list with a manual-entry fallback for tokens that may request
/// credentials but may not list roles. Roles are grouped by mount when
/// there are several.
class RolePicker extends StatefulWidget {
  const RolePicker({
    super.key,
    required this.groups,
    required this.selected,
    required this.onSelected,
    required this.onRefresh,
  });

  final AsyncValue<List<RoleGroup>> groups;

  /// Selected `(group, role)`.
  final (String, String)? selected;
  final void Function(String group, String role) onSelected;
  final VoidCallback onRefresh;

  @override
  State<RolePicker> createState() => _RolePickerState();
}

class _RolePickerState extends State<RolePicker> {
  final _manual = TextEditingController();
  String? _manualGroup;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups.value ?? const <RoleGroup>[];
    final named = groups.length > 1;
    final manualGroup = groups.any((g) => g.name == _manualGroup)
        ? _manualGroup!
        : groups.firstOrNull?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Roles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Refresh roles',
              icon: const Icon(Icons.refresh),
              onPressed: widget.onRefresh,
            ),
          ],
        ),
        if (named)
          DropdownButtonFormField<String>(
            value: manualGroup,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Mount for a typed role',
            ),
            items: [
              for (final g in groups)
                DropdownMenuItem(value: g.name, child: Text(g.name)),
            ],
            onChanged: (v) => setState(() => _manualGroup = v),
          ),
        TextField(
          controller: _manual,
          decoration: const InputDecoration(
            labelText: 'Role name',
            hintText: 'Type a role and press Enter',
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onSelected(manualGroup, v.trim());
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AsyncValueView<List<RoleGroup>>(
            value: widget.groups,
            isEmpty: (g) => g.every((x) => x.roles.isEmpty && x.error == null),
            empty: 'No roles found.',
            onRetry: widget.onRefresh,
            data: (groups) => ListView(
              children: [
                for (final group in groups) ...[
                  if (named)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        group.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  if (group.error != null)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.error_outline),
                      title: Text(group.error!),
                    )
                  else if (named && group.roles.isEmpty)
                    const ListTile(dense: true, title: Text('No roles.')),
                  for (final role in group.roles)
                    ListTile(
                      dense: true,
                      title: Text(role),
                      selected: (group.name, role) == widget.selected,
                      onTap: () => widget.onSelected(group.name, role),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
