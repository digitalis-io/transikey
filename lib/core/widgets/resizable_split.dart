import 'package:flutter/material.dart';

/// Two horizontal panels separated by a draggable divider.
class ResizableSplit extends StatefulWidget {
  const ResizableSplit({
    super.key,
    required this.left,
    required this.right,
    this.initialLeftWidth = 280,
    this.minLeftWidth = 180,
    this.minRightWidth = 320,
  });

  final Widget left;
  final Widget right;
  final double initialLeftWidth;
  final double minLeftWidth;
  final double minRightWidth;

  @override
  State<ResizableSplit> createState() => _ResizableSplitState();
}

class _ResizableSplitState extends State<ResizableSplit> {
  late double _leftWidth = widget.initialLeftWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final max = (constraints.maxWidth - widget.minRightWidth).clamp(
        widget.minLeftWidth,
        double.infinity,
      );
      final width = _leftWidth.clamp(widget.minLeftWidth, max);
      return Row(
        children: [
          SizedBox(width: width, child: widget.left),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) =>
                  setState(() => _leftWidth = width + d.delta.dx),
              child: const SizedBox(
                width: 9,
                child: Center(child: VerticalDivider(width: 1)),
              ),
            ),
          ),
          Expanded(child: widget.right),
        ],
      );
    },
  );
}
