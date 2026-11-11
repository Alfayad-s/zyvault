import 'dart:math' as math;

import 'package:finance_track/haptics.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FinanceBottomBar extends StatelessWidget {
  const FinanceBottomBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.onLog,
    this.onLend,
    this.showPlans = true,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onLog;
  final VoidCallback? onLend;
  final bool showPlans;

  static const labels = ['Home', 'Activity', 'Money', 'Scheduled'];
  static const icons = [
    LucideIcons.pentagon,
    LucideIcons.database,
    LucideIcons.indianRupee,
    LucideIcons.calendarClock,
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var item = 0; item < labels.length; item++)
                        if (showPlans || item != 3)
                          _NavItem(
                            label: labels[item],
                            icon: icons[item],
                            selected: index == item,
                            onTap: () => onChanged(item),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _AddButton(onLog: onLog, onLend: onLend),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.onLog, this.onLend});

  final VoidCallback onLog;
  final VoidCallback? onLend;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  static const _size = 60.0;
  static const _satellite = 84.0;
  static const _radius = 112.0;
  static const _ink = Color(0xFF161616);

  final _key = GlobalKey();
  late final AnimationController _motion;
  OverlayEntry? _menu;
  var _open = false;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _motion.addListener(() => _menu?.markNeedsBuild());
  }

  @override
  void dispose() {
    _menu?.remove();
    _menu = null;
    _motion.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _close();
      return;
    }
    setState(() => _open = true);
    _menu = OverlayEntry(builder: _buildMenu);
    Overlay.of(context).insert(_menu!);
    _motion.forward(from: 0);
  }

  void _close() {
    if (_menu == null || _closing) return;
    _closing = true;
    _motion.reverse().whenComplete(() {
      _closing = false;
      if (!mounted || _menu == null) return;
      _menu!.remove();
      _menu = null;
      setState(() => _open = false);
    });
  }

  void _choose(VoidCallback action) {
    _closing = false;
    _menu?.remove();
    _menu = null;
    _motion.stop();
    _motion.value = 0;
    if (mounted) setState(() => _open = false);
    action();
  }

  Offset _spot(Offset origin, double travel, double lean) {
    final theta = -math.pi / 2 + lean;
    return origin + Offset(math.cos(theta), math.sin(theta)) * _radius * travel;
  }

  Widget _buildMenu(BuildContext context) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return const SizedBox.shrink();
    final origin = box.localToGlobal(box.size.center(Offset.zero));
    final travel = Curves.easeOutBack.transform(_motion.value).clamp(0.0, 1.15);
    final screen = MediaQuery.sizeOf(context);
    final lean = screen.width - origin.dx < 120 ? -0.55 : 0.0;
    final log = _spot(origin, travel, widget.onLend == null ? 0 : -0.72 + lean);
    final lend = _spot(origin, travel, 0.72 + lean);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: withTapHaptic(_close),
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Color(0x66000000)),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GooeyNecks(
                origin: origin,
                ends: widget.onLend == null ? [log] : [log, lend],
                progress: _motion.value,
              ),
            ),
          ),
        ),
        _Satellite(
          center: log,
          icon: LucideIcons.penLine,
          label: 'Log',
          scale: travel.clamp(0.0, 1.0),
          onTap: () => _choose(widget.onLog),
        ),
        if (widget.onLend != null)
          _Satellite(
            center: lend,
            icon: LucideIcons.handCoins,
            label: 'Lend or borrow',
            scale: travel.clamp(0.0, 1.0),
            onTap: () => _choose(widget.onLend!),
          ),
        Positioned(
          left: origin.dx - _size / 2,
          top: origin.dy - _size / 2,
          child: Semantics(
            button: true,
            label: 'Close',
            child: GestureDetector(
              onTap: withTapHaptic(_close),
              child: Container(
                width: _size,
                height: _size,
                decoration: const BoxDecoration(
                  color: _ink,
                  shape: BoxShape.circle,
                ),
                child: Transform.rotate(
                  angle: _motion.value * math.pi / 4,
                  child: const Icon(
                    LucideIcons.plus,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: _open,
      child: Semantics(
        button: true,
        label: 'Add',
        child: GestureDetector(
          key: _key,
          onTap: withTapHaptic(_toggle),
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: _ink,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, child) => Transform.rotate(
                angle: _motion.value * math.pi / 4,
                child: child,
              ),
              child: const Icon(
                LucideIcons.plus,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Satellite extends StatelessWidget {
  const _Satellite({
    required this.center,
    required this.icon,
    required this.label,
    required this.scale,
    required this.onTap,
  });

  final Offset center;
  final IconData icon;
  final String label;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = _AddButtonState._satellite;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: Transform.scale(
        scale: scale,
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: withTapHaptic(onTap),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: _AddButtonState._ink,
                shape: BoxShape.circle,
              ),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: size - 22,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GooeyNecks extends CustomPainter {
  const _GooeyNecks({
    required this.origin,
    required this.ends,
    required this.progress,
  });

  final Offset origin;
  final List<Offset> ends;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _AddButtonState._ink.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 22 * progress;
    for (final end in ends) {
      final mid = Offset(
        (origin.dx + end.dx) / 2,
        math.min(origin.dy, end.dy) - 8,
      );
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GooeyNecks old) =>
      old.progress != progress || old.origin != origin;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : const Color(0xFF8E8E93);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: withTapHaptic(onTap),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 52,
          height: 48,
          child: Center(child: Icon(icon, color: color, size: 22)),
        ),
      ),
    );
  }
}
