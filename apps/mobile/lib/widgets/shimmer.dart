import 'package:flutter/material.dart';

/// A soft highlight that sweeps across skeleton shapes.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = !MediaQuery.disableAnimationsOf(context);
    if (enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final travel = bounds.width * 1.6;
            final dx = -travel + _controller.value * (bounds.width + travel * 2);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0x00FFFFFF),
                Color(0x38FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.36, 0.5, 0.64],
            ).createShader(Rect.fromLTWH(dx, bounds.top, travel, bounds.height));
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ShimmerBone extends StatelessWidget {
  const ShimmerBone({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
    this.color = const Color(0xFF2C2C2E),
  });

  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Short bar shown inside a button while an action is in flight.
class ShimmerBusy extends StatelessWidget {
  const ShimmerBusy({super.key});

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: ShimmerBone(
        width: 84,
        height: 14,
        radius: 7,
        color: Color(0xFF5C5C60),
      ),
    );
  }
}

class ShimmerRows extends StatelessWidget {
  const ShimmerRows({
    super.key,
    this.count = 6,
    this.padding,
    this.scroll = true,
    this.inset = 20,
  });

  final int count;
  final EdgeInsetsGeometry? padding;
  final bool scroll;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (var index = 0; index < count; index++) ...[
        if (index > 0) const SizedBox(height: 4),
        _ShimmerRow(inset: inset),
      ],
    ];
    return Shimmer(
      child: scroll
          ? ListView(
              padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
              physics: const AlwaysScrollableScrollPhysics(),
              children: rows,
            )
          : Padding(
              padding: padding ?? EdgeInsets.zero,
              child: Column(children: rows),
            ),
    );
  }
}

class _ShimmerRow extends StatelessWidget {
  const _ShimmerRow({required this.inset});

  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: 12),
      child: const Row(
        children: [
          ShimmerBone(width: 40, height: 40, radius: 20),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBone(width: 132, height: 14, radius: 7),
                SizedBox(height: 8),
                ShimmerBone(width: 88, height: 11, radius: 6),
              ],
            ),
          ),
          SizedBox(width: 16),
          ShimmerBone(width: 56, height: 14, radius: 7),
        ],
      ),
    );
  }
}

/// Shown while the saved session is restored, before any screen is known.
class BootShimmer extends StatelessWidget {
  const BootShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Shimmer(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBone(width: 148, height: 22, radius: 8),
                SizedBox(height: 22),
                ShimmerBone(width: double.infinity, height: 196, radius: 28),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: ShimmerBone(height: 136, radius: 22)),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerBone(height: 136, radius: 22)),
                  ],
                ),
                SizedBox(height: 16),
                ShimmerBone(width: double.infinity, height: 168, radius: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
