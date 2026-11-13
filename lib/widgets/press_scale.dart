import 'package:material_ui/material_ui.dart';

/// Scales [child] down slightly while a pointer is held on it.
///
/// Uses a [Listener] so it never competes with the child's own gesture
/// handling (for example a [FloatingActionButton]'s tap).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.92});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
