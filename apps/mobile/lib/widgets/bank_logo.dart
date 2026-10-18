import 'package:finance_track/models.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BankLogo extends StatelessWidget {
  const BankLogo({
    super.key,
    this.bank,
    this.width = 64,
    this.height = 40,
    this.cash = false,
  }) : round = false;

  const BankLogo.round({
    super.key,
    this.bank,
    double size = 40,
    this.cash = false,
  }) : width = size,
       height = size,
       round = true;

  final Bank? bank;
  final double width;
  final double height;
  final bool cash;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final shape = round
        ? const BoxDecoration(shape: BoxShape.circle)
        : BoxDecoration(borderRadius: BorderRadius.circular(height * 0.28));
    final bank = this.bank;
    if (bank == null || bank.id == 'other') {
      return Container(
        width: width,
        height: height,
        decoration: shape.copyWith(
          color: cash ? const Color(0xFF2E7D32) : const Color(0xFF3A3A3C),
        ),
        child: Icon(
          cash ? LucideIcons.wallet : LucideIcons.landmark,
          color: Colors.white,
          size: height * 0.5,
        ),
      );
    }
    final fallback = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: shape.copyWith(color: Color(bank.color)),
      padding: EdgeInsets.all(height * (round ? 0.22 : 0.18)),
      child: FittedBox(
        child: Text(
          bank.short,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    final url = round ? bank.markUrl : bank.logoUrl;
    if (url == null) return fallback;
    return Container(
      width: width,
      height: height,
      padding: round
          ? EdgeInsets.all(height * 0.16)
          : EdgeInsets.symmetric(
              horizontal: height * 0.16,
              vertical: height * 0.14,
            ),
      decoration: shape.copyWith(color: Colors.white),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        semanticLabel: bank.name,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, synchronous) =>
            frame == null && !synchronous
            ? OverflowBox(maxWidth: width, maxHeight: height, child: fallback)
            : child,
        errorBuilder: (context, error, stackTrace) =>
            OverflowBox(maxWidth: width, maxHeight: height, child: fallback),
      ),
    );
  }
}
