// Flutter port of the "working" state from thinking-orbs
// (https://libraries.dev/orbs.html), MIT License, Copyright (c) 2026 Jakub Antalik.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ThinkingOrb extends StatefulWidget {
  const ThinkingOrb({
    super.key,
    this.size = 64,
    this.speed = 1,
    this.dark = true,
    this.paused = false,
  });

  final double size;
  final double speed;
  final bool dark;
  final bool paused;

  @override
  State<ThinkingOrb> createState() => _ThinkingOrbState();
}

class _ThinkingOrbState extends State<ThinkingOrb>
    with SingleTickerProviderStateMixin {
  static const _presetSpeed = 1.885;

  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0.6);
  final _still = ValueNotifier<double>(0.6);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final delta = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      _time.value += delta * _presetSpeed * widget.speed;
    });
    if (!widget.paused) _ticker.start();
  }

  @override
  void didUpdateWidget(ThinkingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused && _ticker.isActive) {
      _ticker.stop();
    } else if (!widget.paused && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _still.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: 'Thinking',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _OrbitsPainter(
            time: reduced ? _still : _time,
            dark: widget.dark,
          ),
        ),
      ),
    );
  }
}

class _Dot {
  const _Dot(this.x, this.y, this.z, this.r, this.white, this.alpha);

  final double x;
  final double y;
  final double z;
  final double r;
  final double white;
  final double alpha;
}

class _OrbitsPainter extends CustomPainter {
  _OrbitsPainter({required this.time, required this.dark})
    : super(repaint: time);

  final ValueNotifier<double> time;
  final bool dark;

  static const _orbitN = 12;
  static const _ghostN = 40;
  static const _particles = 3;
  static const _ghostR = 0.9;
  static const _ghostA = 0.5;
  static const _partR = 1.2;
  static const _partRDepth = 1.6;
  static const _rMin = 0.3;

  static double _hash(double a, double b) {
    final h = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
    return h - h.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final side = size.shortestSide;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = side / 2 * 0.82;
    final rs = math.pow(side / 300, 0.6).toDouble();

    final yaw = t * 0.12;
    const tilt = 0.3;
    final sinTilt = math.sin(tilt);
    final cosTilt = math.cos(tilt);
    final sinYaw = math.sin(yaw);
    final cosYaw = math.cos(yaw);
    (double, double, double) project(double x, double y, double z) {
      final x1 = x * cosYaw + z * sinYaw;
      final z1 = -x * sinYaw + z * cosYaw;
      final y1 = y * cosTilt - z1 * sinTilt;
      final z2 = y * sinTilt + z1 * cosTilt;
      return (cx + x1, cy - y1, z2);
    }

    final dots = <_Dot>[];
    for (var orbit = 0; orbit < _orbitN; orbit++) {
      final h1 = _hash(orbit.toDouble(), 1.7);
      final h2 = _hash(orbit.toDouble(), 5.2);
      final h3 = _hash(orbit.toDouble(), 8.9);
      final ro = radius * (0.45 + 0.52 * h1);
      final theta = h1 * 2 * math.pi;
      final phi = math.acos(2 * h2 - 1);
      final nx = math.sin(phi) * math.cos(theta);
      final ny = math.cos(phi);
      final nz = math.sin(phi) * math.sin(theta);
      var ux = -ny;
      var uy = nx;
      const uz = 0.0;
      final length = math.max(1e-6, math.sqrt(ux * ux + uy * uy));
      ux /= length;
      uy /= length;
      final vx = ny * uz - nz * uy;
      final vy = nz * ux - nx * uz;
      final vz = nx * uy - ny * ux;
      final speed = (0.25 + 0.55 * h3) * (h3 > 0.5 ? 1 : -1);

      (double, double, double) at(double a) => project(
        (ux * math.cos(a) + vx * math.sin(a)) * ro,
        (uy * math.cos(a) + vy * math.sin(a)) * ro,
        (uz * math.cos(a) + vz * math.sin(a)) * ro,
      );

      for (var k = 0; k < _ghostN; k++) {
        final (px, py, z) = at(k / _ghostN * 2 * math.pi);
        final depth = (z / ro + 1) / 2;
        dots.add(
          _Dot(px, py, z, _ghostR * rs, 0.72, _ghostA * (0.4 + 0.6 * depth)),
        );
      }
      for (var m = 0; m < _particles; m++) {
        final (px, py, z) = at(
          t * speed + m / _particles * 2 * math.pi + h2 * 6,
        );
        final depth = (z / ro + 1) / 2;
        dots.add(
          _Dot(
            px,
            py,
            z,
            (_partR + _partRDepth * depth) * rs,
            0.3 - 0.22 * depth,
            1,
          ),
        );
      }
    }

    dots.sort((a, b) => a.z.compareTo(b.z));
    final paint = Paint()..isAntiAlias = true;
    for (final dot in dots) {
      if (dot.alpha < 0.02) continue;
      final ink = dot.white.clamp(0.0, 1.0);
      final gray = ((dark ? 1 - ink : ink) * 255).round();
      paint.color = Color.fromARGB((dot.alpha * 255).round(), gray, gray, gray);
      canvas.drawCircle(Offset(dot.x, dot.y), math.max(_rMin, dot.r), paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitsPainter oldDelegate) {
    return oldDelegate.dark != dark || oldDelegate.time != time;
  }
}
