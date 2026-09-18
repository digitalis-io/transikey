import 'package:flutter/material.dart';

/// Read-only value that is masked until the user reveals it. [onCopy]
/// receives the clear value; callers route it through the clipboard guard.
class SecretField extends StatefulWidget {
  const SecretField({
    super.key,
    required this.label,
    required this.value,
    required this.onCopy,
    this.sensitive = true,
    this.multiline = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onCopy;
  final bool sensitive;
  final bool multiline;

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool _revealed = false;

  @override
  void didUpdateWidget(SecretField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hidden = widget.sensitive && !_revealed;
    final text = hidden ? '•' * 16 : widget.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(widget.label, style: theme.textTheme.labelLarge),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                text,
                maxLines: widget.multiline && !hidden ? 8 : 1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          if (widget.sensitive)
            IconButton(
              tooltip: _revealed ? 'Hide' : 'Reveal',
              icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _revealed = !_revealed),
            ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: () => widget.onCopy(widget.value),
          ),
        ],
      ),
    );
  }
}
