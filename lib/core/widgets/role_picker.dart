import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'async_value_view.dart';

/// Role list with a manual-entry fallback for tokens that may request
/// credentials but may not list roles.
class RolePicker extends StatefulWidget {
  const RolePicker({
    super.key,
    required this.roles,
    required this.selected,
    required this.onSelected,
    required this.onRefresh,
  });

  final AsyncValue<List<String>> roles;
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onRefresh;

  @override
  State<RolePicker> createState() => _RolePickerState();
}

class _RolePickerState extends State<RolePicker> {
  final _manual = TextEditingController();

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
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
      TextField(
        controller: _manual,
        decoration: const InputDecoration(
          labelText: 'Role name',
          hintText: 'Type a role and press Enter',
        ),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) widget.onSelected(v.trim());
        },
      ),
      const SizedBox(height: 8),
      Expanded(
        child: AsyncValueView<List<String>>(
          value: widget.roles,
          isEmpty: (r) => r.isEmpty,
          empty: 'No roles found on this mount.',
          onRetry: widget.onRefresh,
          data: (roles) => ListView(
            children: [
              for (final role in roles)
                ListTile(
                  dense: true,
                  title: Text(role),
                  selected: role == widget.selected,
                  onTap: () => widget.onSelected(role),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
