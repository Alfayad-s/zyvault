import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// The Libraries.dev Flower bot, drawn in Flutter from the same outline,
/// colour, eye spacing and motion as `bot-avatars` (`type="flower"`).
/// Idle looks around and blinks. A tap hops without turning. Working hops, and every third hop spins.
class FlowerAvatar extends StatefulWidget {
  const FlowerAvatar({
    super.key,
    this.working = false,
    this.animate = true,
    this.size = 64,
  });

  final bool working;
  final bool animate;
  final double size;

  @override
  State<FlowerAvatar> createState() => _FlowerAvatarState();
}

class _FlowerAvatarState extends State<FlowerAvatar> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _pose = ValueNotifier<_Pose>(const _Pose());
  var _last = Duration.zero;
  var _t = 0.0;
  var _roll = 0.0;
  var _lookX = 0.0;
  var _lookY = 0.0;
  var _y = 0.0;
  var _sx = 1.0;
  var _sy = 1.0;
  var _ptrX = 0.0;
  var _ptrY = 0.0;
  var _ptr = 0.0;
  var _jumpFrom = -1.0;
  var _jumpMark = 0;
  var _nextIdleJump = 9.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    if (widget.animate) _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (!mounted || dt == 0) return;
    _t += dt;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) return;

    final gaze = widget.working ? 0.0 : _held(_t, 3.6, 1.4);
    final wantRoll = _lerp(gaze * 0.16, _ptrX * 0.28, _ptr);
    final wantLookX = _lerp(gaze * 2.2, _ptrX * 5.5, _ptr);
    final wantLookY = _lerp(math.sin(_t * 0.55) * 0.35, _ptrY * 3.2, _ptr);
    _roll = _approach(_roll, wantRoll, 4.5, dt);
    _lookX = _approach(_lookX, wantLookX, 8, dt);
    _lookY = _approach(_lookY, wantLookY, 8, dt);

    final breath = math.sin(_t * 1.15);
    var y = breath * 0.45;
    var sx = 1 + breath * 0.01;
    var sy = 1 - breath * 0.008;
    if (widget.working && _jumpFrom < 0) {
      _jumpFrom = _t;
      _jumpMark = 3;
      _jumpMarkForTouch = false;
    }
    if (!widget.working && _jumpFrom < 0 && _t >= _nextIdleJump) {
      _jumpFrom = _t;
      _jumpMark = 3;
      _nextIdleJump = _t + 9;
    }
    final age = _jumpFrom < 0 ? -1.0 : _t - _jumpFrom;
    final jump = age < 0 ? null : _ballistic(age);
    if (age >= 0 && jump == null) {
      _jumpFrom = -1;
      _jumpMarkForTouch = false;
    }
    if (jump != null) {
      y = jump.y;
      sx = jump.sx;
      sy = jump.sy;
      if (_jumpMarkForTouch && _jumpMark == 0 && age >= _crouch) {
        _jumpMark = 1;
        HapticFeedback.selectionClick();
      }
      if (_jumpMarkForTouch && _jumpMark == 1 && age >= _crouch + _flight) {
        _jumpMark = 2;
        HapticFeedback.mediumImpact();
      }
      _y = y;
      _sx = sx;
      _sy = sy;
    } else {
      _y = _approach(_y, y, 14, dt);
      _sx = _approach(_sx, sx, 14, dt);
      _sy = _approach(_sy, sy, 14, dt);
    }
    _pose.value = _Pose(y: _y, sx: _sx, sy: _sy, roll: _roll, lookX: _lookX, lookY: _lookY, eyeOpen: _blink(_t));
  }

  bool _jumpMarkForTouch = false;

  void _point(Offset local, Size box) {
    final dx = (local.dx - box.width / 2) / widget.size;
    final dy = (local.dy - box.height / 2) / widget.size;
    final reach = math.sqrt(dx * dx + dy * dy);
    _ptrX = dx.clamp(-1.1, 1.1);
    _ptrY = dy.clamp(-1.1, 1.1);
    _ptr = reach < 0.45 ? 1 : reach > 2.2 ? 0 : 1 - (reach - 0.45) / 1.75;
    if (!_ticker.isActive && widget.animate) _ticker.start();
  }

  void _release() => _ptr = 0;

  void _poke() {
    if (!widget.animate || _jumpFrom >= 0) return;
    _jumpFrom = _t;
    _jumpMark = 0;
    _jumpMarkForTouch = true;
    HapticFeedback.lightImpact();
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  void didUpdateWidget(FlowerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_ticker.isActive) _ticker.start();
    if (!widget.animate && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final live = widget.animate && !reduce;
    return Semantics(
      label: widget.working ? 'Flower, working' : 'Flower, idle',
      button: live,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: live ? _poke : null,
          child: Listener(
            onPointerDown: live ? (event) => _point(event.localPosition, Size(widget.size, widget.size)) : null,
            onPointerMove: live ? (event) => _point(event.localPosition, Size(widget.size, widget.size)) : null,
            onPointerHover: live ? (event) => _point(event.localPosition, Size(widget.size, widget.size)) : null,
            onPointerUp: live ? (_) => _release() : null,
            onPointerCancel: live ? (_) => _release() : null,
            child: OverflowBox(
              maxWidth: widget.size * 1.85,
              maxHeight: widget.size * 2,
              alignment: const Alignment(0, 0.28),
              child: CustomPaint(
                size: Size(widget.size * 1.85, widget.size * 2),
                painter: _FlowerPainter(pose: live ? _pose : null, layout: widget.size),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowerPainter extends CustomPainter {
  _FlowerPainter({required this.pose, required this.layout}) : super(repaint: pose);

  final ValueNotifier<_Pose>? pose;
  final double layout;

  @override
  void paint(Canvas canvas, Size size) {
    final current = pose?.value ?? const _Pose();
    final s = layout / 100;
    final origin = Offset(size.width / 2, size.height * 0.58);

    canvas.save();
    canvas.translate(origin.dx, origin.dy + current.y * s);
    canvas.rotate(current.roll);
    canvas.scale(current.sx * s, current.sy * s);
    canvas.translate(-50, -50);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 90), width: 46, height: 10),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    _solid(canvas);
    _surface(canvas);
    _eyes(canvas, current);
    canvas.restore();
  }

  /// Stacked slices give the body thickness, like a cushion seen from the front.
  void _solid(Canvas canvas) {
    const slices = 16;
    for (var i = 0; i < slices; i++) {
      final z = -1 + (2 * i) / (slices - 1);
      final puff = 0.78 + 0.22 * math.sqrt(math.max(0.0, 1 - z * z));
      final shade = Color.lerp(const Color(0xFF0E7A40), const Color(0xFF7DFFAA), i / (slices - 1))!;
      canvas.save();
      canvas.translate(50, 50 + z * -1.1);
      canvas.scale(puff, puff * (0.9 + 0.1 * ((z + 1) / 2)));
      canvas.translate(-50, -50);
      canvas.drawPath(_flower, Paint()..color = shade);
      canvas.restore();
    }
    canvas.drawPath(
      _flower,
      Paint()
        ..color = const Color(0xAAE9FFE8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5),
    );
  }

  void _surface(Canvas canvas) {
    canvas.save();
    canvas.clipPath(_flower);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.32, -0.46),
          radius: 1.15,
          colors: [Color(0xCCFFFFFF), Color(0x223DDC86), Color(0x00102A18)],
          stops: [0.0, 0.42, 1],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()
        ..blendMode = BlendMode.multiply
        ..shader = const RadialGradient(
          center: Alignment(0.55, 0.7),
          radius: 1.1,
          colors: [Color(0xAA0C3D22), Color(0x000C3D22)],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    canvas.saveLayer(
      const Rect.fromLTWH(-8, -8, 116, 116),
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 0.7, sigmaY: 0.7),
    );
    for (final hair in _coat) {
      canvas.drawLine(hair.$1, hair.$2, hair.$3);
    }
    canvas.restore();
    canvas.restore();
    canvas.saveLayer(
      const Rect.fromLTWH(-18, -18, 136, 136),
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 1.15, sigmaY: 1.15),
    );
    for (final strand in _fringe) {
      canvas.drawLine(strand.$1, strand.$2, strand.$3);
    }
    canvas.restore();
  }

  void _eyes(Canvas canvas, _Pose pose) {
    final open = pose.eyeOpen.clamp(0.15, 1.0);
    final ink = Paint()..color = const Color(0xFF16181F);
    for (final side in [-1.0, 1.0]) {
      final center = Offset(50 + side * 11.2 + pose.lookX, 51.5 + pose.lookY);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, open);
      canvas.drawCircle(
        const Offset(0, 0.6),
        6.6,
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
      canvas.drawCircle(Offset.zero, 5.7, ink);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FlowerPainter oldDelegate) => oldDelegate.layout != layout || oldDelegate.pose != pose;
}

class _Pose {
  const _Pose({
    this.y = 0,
    this.sx = 1,
    this.sy = 1,
    this.roll = 0,
    this.lookX = 0,
    this.lookY = 0,
    this.eyeOpen = 1,
  });

  final double y;
  final double sx;
  final double sy;
  final double roll;
  final double lookX;
  final double lookY;
  final double eyeOpen;
}

double _approach(double current, double target, double rate, double dt) {
  return current + (target - current) * (1 - math.exp(-rate * dt));
}

double _lerp(double idle, double touched, double amount) => idle + (touched - idle) * amount;

/// Holds a side, then eases to the other. Returns −1…1.
double _held(double t, double hold, double swing) {
  final cycle = hold + swing;
  final local = t % (cycle * 2);
  double side(double at) {
    if (at < hold) return -1;
    if (at < cycle) return -1 + _ease((at - hold) / swing) * 2;
    if (at < cycle + hold) return 1;
    return 1 - _ease((at - cycle - hold) / swing) * 2;
  }

  return side(local);
}

double _ease(double p) => p < 0.5 ? 4 * p * p * p : 1 - math.pow(-2 * p + 2, 3) / 2;

const _crouch = 0.12;
const _flight = 0.46;
const _settle = 0.38;

/// Crouch, a gravity arc, then a damped landing squash. Positive y is down.
({double y, double sx, double sy})? _ballistic(double age) {
  if (age < _crouch) {
    final u = _ease(age / _crouch);
    return (y: 3.4 * u, sx: 1 + 0.2 * u, sy: 1 - 0.22 * u);
  }
  final air = age - _crouch;
  if (air < _flight) {
    final u = air / _flight;
    final height = 4 * 22 * u * (1 - u);
    final stretch = math.sin(u * math.pi);
    return (y: -height, sx: 1 - 0.08 * stretch, sy: 1 + 0.12 * stretch);
  }
  final land = age - _crouch - _flight;
  if (land < _settle) {
    final u = land / _settle;
    final bounce = math.exp(-6.2 * u) * math.cos(u * math.pi * 3);
    return (y: 2.6 * bounce, sx: 1 + 0.22 * bounce, sy: 1 - 0.18 * bounce);
  }
  return null;
}

double _blink(double t) {
  const gap = 3.4;
  const shut = 0.17;
  final local = t % gap;
  if (local > shut) return 1;
  final u = local / shut;
  return u < 0.5 ? 1 - u * 2 : (u - 0.5) * 2;
}

/// Official flower outline, 100×100, centred on (50, 50).
final Path _flower = Path()
  ..moveTo(31.2, 19.82)
  ..arcToPoint(const Offset(68.8, 19.82), radius: const Radius.circular(20.5), clockwise: true)
  ..arcToPoint(const Offset(72.9, 22.8), radius: const Radius.circular(5), clockwise: false)
  ..arcToPoint(const Offset(84.51, 58.55), radius: const Radius.circular(20.5), clockwise: true)
  ..arcToPoint(const Offset(82.95, 63.37), radius: const Radius.circular(5), clockwise: false)
  ..arcToPoint(const Offset(52.54, 85.47), radius: const Radius.circular(20.5), clockwise: true)
  ..arcToPoint(const Offset(47.46, 85.47), radius: const Radius.circular(5), clockwise: false)
  ..arcToPoint(const Offset(17.05, 63.37), radius: const Radius.circular(20.5), clockwise: true)
  ..arcToPoint(const Offset(15.49, 58.55), radius: const Radius.circular(5), clockwise: false)
  ..arcToPoint(const Offset(27.1, 22.8), radius: const Radius.circular(20.5), clockwise: true)
  ..arcToPoint(const Offset(31.2, 19.82), radius: const Radius.circular(5), clockwise: false)
  ..close();

final List<(Offset, Offset, Paint)> _coat = _coatHairs();
final List<(Offset, Offset, Paint)> _fringe = _fringeHairs();

List<(Offset, Offset, Paint)> _coatHairs() {
  final hairs = <(Offset, Offset, Paint)>[];
  for (var y = 10.0; y <= 90; y += 2.6) {
    for (var x = 10.0; x <= 90; x += 2.6) {
      final point = Offset(x, y);
      if (!_flower.contains(point)) continue;
      final from = point - const Offset(50, 48);
      final edge = (from.distance / 36).clamp(0.0, 1.0);
      final n = (x * 17 + y * 9).floor();
      final comb = Offset(from.dx * 0.02 + ((n % 5) - 2) * 0.22, 0.85 + (n % 3) * 0.12);
      final length = comb.distance;
      if (length < 0.2) continue;
      final dir = comb / length;
      final light = ((-from.dx - from.dy) / 70).clamp(0.0, 1.0);
      final color = Color.lerp(const Color(0xFF1C9A52), const Color(0xFFF4FFF6), 0.25 + light * 0.7)!;
      hairs.add((
        point,
        point + dir * (1.5 + edge * 1.8),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.15
          ..color = color.withValues(alpha: 0.42 + edge * 0.35),
      ));
    }
  }
  return hairs;
}

List<(Offset, Offset, Paint)> _fringeHairs() {
  final hairs = <(Offset, Offset, Paint)>[];
  for (final metric in _flower.computeMetrics()) {
    for (var distance = 0.0; distance < metric.length; distance += 1.5) {
      final tangent = metric.getTangentForOffset(distance);
      if (tangent == null) continue;
      final out = tangent.position - const Offset(50, 50);
      final span = out.distance;
      if (span < 1) continue;
      final dir = out / span;
      final bend = Offset(-dir.dy, dir.dx) * (((distance * 3).floor() % 5) - 2) * 0.45;
      final reach = 4.8 + (distance % 3);
      hairs.add((
        tangent.position - dir * 1.2,
        tangent.position + dir * reach + bend + const Offset(0, 1.1),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.35
          ..color = const Color(0xD8CFFFD8),
      ));
    }
  }
  return hairs;
}
