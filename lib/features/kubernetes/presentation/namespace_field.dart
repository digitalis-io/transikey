import 'dart:convert';

import 'package:flutter/material.dart';

/// Namespace input with a filtered list of known namespaces: the ones used
/// before with this role first, then the ones the role allows. Free text
/// always works, for roles that allow any namespace or that the token may
/// not read.
class NamespaceField extends StatefulWidget {
  const NamespaceField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.recent = const [],
    this.allowed = const [],
    this.helperText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> recent;
  final List<String> allowed;
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
  /// often arrive after the field was filled in.
  List<String> get _offered {
    final options = _options;
    final text = widget.controller.text.trim();
    // A filled-in name is a starting point, not a filter: show them all.
    if (text.isEmpty || options.contains(text)) return options;
    final query = text.toLowerCase();
    return [
      for (final n in options)
        if (n.toLowerCase().contains(query)) n,
    ];
  }

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

  void _choose(String namespace) {
    widget.controller.value = TextEditingValue(
      text: namespace,
      selection: TextSelection.collapsed(offset: namespace.length),
    );
    _menu.close();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    childFocusNode: widget.focusNode,
    // Scrolls instead of growing: a role may allow many namespaces.
    style: const MenuStyle(maximumSize: WidgetStatePropertyAll(Size(260, 240))),
    menuChildren: [
      for (final n in _offered)
        MenuItemButton(
          onPressed: () => _choose(n),
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
      decoration: InputDecoration(
        labelText: 'Namespace',
        helperText: widget.helperText,
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
