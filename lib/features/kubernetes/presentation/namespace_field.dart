import 'dart:convert';

import 'package:flutter/material.dart';

/// Namespace picker: several namespaces, one token each. The list holds
/// the namespaces used before with this role first, then the ones the
/// role allows; typing filters it. A typed name is added with Enter, for
/// roles that allow any namespace or that the token may not read.
class NamespaceField extends StatefulWidget {
  const NamespaceField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.onChanged,
    this.recent = const [],
    this.allowed = const [],
    this.max = 10,
    this.helperText,
  });

  /// What is typed: a filter for the list and a name to add.
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final List<String> recent;
  final List<String> allowed;
  final int max;
  final String? helperText;

  @override
  State<NamespaceField> createState() => _NamespaceFieldState();
}

class _NamespaceFieldState extends State<NamespaceField> {
  final _menu = MenuController();

  /// Recent first, then allowed ones not already listed.
  List<String> get _options => [
    ...widget.recent,
    for (final n in widget.allowed)
      if (!widget.recent.contains(n)) n,
  ];

  /// Built from the current widget on every call: the role's namespaces
  /// often arrive after the field is on screen.
  List<String> get _offered {
    final query = widget.controller.text.trim().toLowerCase();
    return [
      for (final n in _options)
        if (query.isEmpty || n.toLowerCase().contains(query)) n,
    ];
  }

  bool get _full => widget.selected.length >= widget.max;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_sync);
    widget.controller.addListener(_sync);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_sync);
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  /// Open while the field has focus and something matches.
  void _sync() {
    if (!mounted) return;
    setState(() {});
    final show = widget.focusNode.hasFocus && _offered.isNotEmpty;
    if (show && !_menu.isOpen) _menu.open();
    if (!show && _menu.isOpen && widget.focusNode.hasFocus) _menu.close();
  }

  void _toggle(String namespace) {
    final selected = [...widget.selected];
    if (!selected.remove(namespace)) {
      if (_full) return;
      selected.add(namespace);
    }
    widget.onChanged(selected);
  }

  void _addTyped() {
    final typed = widget.controller.text.trim();
    if (typed.isNotEmpty && !widget.selected.contains(typed) && !_full) {
      widget.onChanged([...widget.selected, typed]);
    }
    widget.controller.clear();
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final field = MenuAnchor(
      controller: _menu,
      childFocusNode: widget.focusNode,
      // Scrolls instead of growing: a role may allow many namespaces.
      style: const MenuStyle(
        maximumSize: WidgetStatePropertyAll(Size(300, 240)),
      ),
      menuChildren: [
        for (final n in _offered)
          CheckboxMenuButton(
            value: widget.selected.contains(n),
            // Stays open: ticking several is the point.
            closeOnActivate: false,
            onChanged: _full && !widget.selected.contains(n)
                ? null
                : (_) => _toggle(n),
            trailingIcon: widget.recent.contains(n)
                ? const Tooltip(
                    message: 'Used before',
                    child: Icon(Icons.history, size: 18),
                  )
                : null,
            child: Text(n),
          ),
      ],
      builder: (context, menu, _) => TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onTap: _sync,
        onSubmitted: (_) => _addTyped(),
        decoration: InputDecoration(
          labelText: 'Namespaces',
          hintText: widget.selected.isEmpty ? null : 'Add another',
          helperText: _full
              ? 'At most ${widget.max} namespaces at once'
              : widget.helperText,
          suffixIcon: _options.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Show namespaces',
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: () {
                    widget.focusNode.requestFocus();
                    menu.isOpen ? menu.close() : menu.open();
                  },
                ),
        ),
      ),
    );
    return field;
  }
}

/// The chosen namespaces as removable chips. Kept out of [NamespaceField]
/// so they can use the full width instead of stacking under the field.
class NamespaceChips extends StatelessWidget {
  const NamespaceChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final n in selected)
        InputChip(
          label: Text(n),
          onDeleted: () => onChanged([...selected]..remove(n)),
          deleteButtonTooltipMessage: 'Remove $n',
        ),
    ],
  );
}

/// Helper line under the namespace field: what the role allows. The
/// server accepts a namespace that is listed or that carries the labels
/// of [selector].
String? namespaceHelp({
  required List<String> allowed,
  required List<String> choices,
  required String selector,
}) {
  if (allowed.contains('*')) return 'Any namespace';
  final listed = choices.isEmpty
      ? null
      : choices.length <= 3
      ? 'Allowed: ${choices.join(', ')}'
      : '${choices.length} allowed, type to filter';
  if (selector.isEmpty) return listed;
  final labels = selectorLabel(selector);
  return listed == null
      ? 'Namespaces labelled $labels'
      : '$listed, or labelled $labels';
}

/// `{"matchLabels":{"team":"payments"}}` -> `team=payments`. Anything else
/// (YAML, expressions) is shown as the server returned it.
String selectorLabel(String selector) {
  try {
    final decoded = jsonDecode(selector);
    final labels = decoded is Map ? decoded['matchLabels'] : null;
    if (labels is Map &&
        labels.isNotEmpty &&
        decoded is Map &&
        decoded['matchExpressions'] == null) {
      return [for (final e in labels.entries) '${e.key}=${e.value}'].join(', ');
    }
  } on FormatException {
    // Not JSON: YAML is valid too.
  }
  return selector;
}
