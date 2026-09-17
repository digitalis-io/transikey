import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Reports pointer and keyboard activity anywhere below it. Calls are
/// throttled to one per second.
class IdleDetector extends StatefulWidget {
  const IdleDetector({
    super.key,
    required this.onActivity,
    required this.child,
  });

  final VoidCallback onActivity;
  final Widget child;

  @override
  State<IdleDetector> createState() => _IdleDetectorState();
}

class _IdleDetectorState extends State<IdleDetector> {
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    _touch();
    return false;
  }

  void _touch() {
    final now = DateTime.now();
    if (now.difference(_last) < const Duration(seconds: 1)) return;
    _last = now;
    widget.onActivity();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _touch(),
    onPointerHover: (_) => _touch(),
    onPointerMove: (_) => _touch(),
    onPointerSignal: (_) => _touch(),
    child: widget.child,
  );
}
