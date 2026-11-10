import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A short tick for a control the person pressed.
void pressHaptic() {
  HapticFeedback.selectionClick();
}

/// Runs [action] after a tap tick. A null action stays null, so a disabled control stays quiet.
VoidCallback? withTapHaptic(VoidCallback? action) {
  if (action == null) return null;
  return () {
    pressHaptic();
    action();
  };
}

/// Plays a tap tick for Material controls (buttons, switches, menu items, list rows).
///
/// Custom [GestureDetector] taps are not semantics buttons, so those call [pressHaptic] themselves.
/// Scroll views are skipped: their semantics handler also tracks a drag.
class TapHaptics extends StatelessWidget {
  const TapHaptics({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderSemanticsGestureHandler &&
          target.onTap != null &&
          target.onHorizontalDragUpdate == null &&
          target.onVerticalDragUpdate == null) {
        pressHaptic();
        return;
      }
    }
  }
}
