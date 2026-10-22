import 'package:flutter/material.dart';

const pullPhysics = AlwaysScrollableScrollPhysics();

class PullRefresh extends StatelessWidget {
  const PullRefresh({super.key, required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF17310C),
      backgroundColor: const Color(0xFFC8F57A),
      onRefresh: onRefresh,
      child: child,
    );
  }
}
