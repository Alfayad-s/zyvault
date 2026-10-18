import 'dart:math' as math;

import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';

class SpendingSlice {
  const SpendingSlice({
    required this.name,
    required this.amount,
    required this.color,
    this.kind = 'expense',
  });

  final String name;
  final int amount;
  final Color color;
  final String kind;
}

const spendingPalette = <Color>[
  Color(0xFF7EC8E3),
  Color(0xFFF4A261),
  Color(0xFF8FCB9B),
  Color(0xFFC084FC),
  Color(0xFF8E8E93),
  Color(0xFF5C6BC0),
  Color(0xFFF6E7A1),
  Color(0xFFB7E4C7),
  Color(0xFFF48FB1),
  Color(0xFFE57373),
];

const _namedColors = <String, Color>{
  'home': Color(0xFF7EC8E3),
  'rent': Color(0xFF7EC8E3),
  'food': Color(0xFFF4A261),
  'transport': Color(0xFFF4A261),
  'education': Color(0xFF8FCB9B),
  'entertainment': Color(0xFFC084FC),
  'other': Color(0xFF8E8E93),
  'charity': Color(0xFF5C6BC0),
  'bills': Color(0xFF5C6BC0),
  'services': Color(0xFFF6E7A1),
  'health': Color(0xFFB7E4C7),
  'shopping': Color(0xFFF48FB1),
  'clothes': Color(0xFFE57373),
  'salary': Color(0xFF8FCB9B),
};

List<SpendingSlice> spendingSlices({
  required String kind,
  required List<Category> categories,
  required List<TransactionItem> transactions,
}) {
  final totals = <String, int>{};
  final names = <String, String>{};
  for (final category in categories.where(
    (category) => category.kind == kind,
  )) {
    totals[category.id] = 0;
    names[category.id] = category.name;
  }
  for (final transaction in transactions.where((item) => item.kind == kind)) {
    totals[transaction.categoryId] =
        (totals[transaction.categoryId] ?? 0) + transaction.amount;
    names[transaction.categoryId] = transaction.categoryName;
  }
  final ids = totals.keys.where((id) => totals[id]! > 0).toList()
    ..sort((a, b) {
      final byAmount = totals[b]!.compareTo(totals[a]!);
      if (byAmount != 0) return byAmount;
      return names[a]!.compareTo(names[b]!);
    });
  return [
    for (var index = 0; index < ids.length; index++)
      SpendingSlice(
        name: names[ids[index]]!,
        amount: totals[ids[index]]!,
        kind: kind,
        color:
            _namedColors[names[ids[index]]!.toLowerCase()] ??
            spendingPalette[index % spendingPalette.length],
      ),
  ];
}

class SpendingCard extends StatelessWidget {
  const SpendingCard({
    super.key,
    required this.kind,
    required this.span,
    required this.previousLabel,
    required this.currentLabel,
    required this.nextLabel,
    required this.slices,
    required this.onKind,
    required this.onSpan,
    required this.onPrevious,
    required this.onNext,
  });

  final String kind;
  final String span;
  final String previousLabel;
  final String currentLabel;
  final String nextLabel;
  final List<SpendingSlice> slices;
  final ValueChanged<String> onKind;
  final ValueChanged<String> onSpan;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _KindMenu(kind: kind, onKind: onKind),
              const Spacer(),
              _SpanPicker(span: span, onSpan: onSpan),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _PeriodLabel(label: previousLabel, onTap: onPrevious),
              ),
              Expanded(
                child: Text(
                  currentLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: _PeriodLabel(
                  label: nextLabel,
                  onTap: onNext,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RingChart(slices: slices),
          const SizedBox(height: 8),
          if (slices.isEmpty)
            const Text(
              'Nothing here yet',
              style: TextStyle(color: Color(0xFF8E8E93)),
            )
          else
            _Legend(slices: slices),
        ],
      ),
    );
  }
}

class _KindMenu extends StatelessWidget {
  const _KindMenu({required this.kind, required this.onKind});

  final String kind;
  final ValueChanged<String> onKind;

  @override
  Widget build(BuildContext context) {
    final label = kind == 'income' ? 'Income' : 'Expenses';
    return PopupMenuButton<String>(
      initialValue: kind,
      onSelected: onKind,
      color: const Color(0xFF3A3A3C),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'expense',
          child: Text('Expenses', style: TextStyle(color: Colors.white)),
        ),
        PopupMenuItem(
          value: 'income',
          child: Text('Income', style: TextStyle(color: Colors.white)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpanPicker extends StatelessWidget {
  const _SpanPicker({required this.span, required this.onSpan});

  final String span;
  final ValueChanged<String> onSpan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in const [
            ('week', 'Week'),
            ('month', 'Month'),
            ('quarter', 'Quarter'),
          ])
            _SpanButton(
              label: item.$2,
              selected: span == item.$1,
              onTap: () => onSpan(item.$1),
            ),
        ],
      ),
    );
  }
}

class _SpanButton extends StatelessWidget {
  const _SpanButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8E8ED) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFF8E8E93),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodLabel extends StatelessWidget {
  const _PeriodLabel({
    required this.label,
    required this.onTap,
    this.alignEnd = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: const TextStyle(color: Color(0xFF6E6E73), fontSize: 16),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.slices});

  final List<SpendingSlice> slices;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < slices.length; index += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: _LegendItem(slices[index])),
              const SizedBox(width: 16),
              Expanded(
                child: index + 1 < slices.length
                    ? _LegendItem(slices[index + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.slice);

  final SpendingSlice slice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: slice.color, width: 2),
          ),
          child: CategoryIcon(name: slice.name, kind: slice.kind, size: 24),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            slice.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFA1A1A6), fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatRupees(slice.amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RingChart extends StatefulWidget {
  const _RingChart({required this.slices});

  final List<SpendingSlice> slices;

  @override
  State<_RingChart> createState() => _RingChartState();
}

class _RingChartState extends State<_RingChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (_hasAmount(widget.slices)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(_RingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameSlices(oldWidget.slices, widget.slices)) return;
    if (_hasAmount(widget.slices)) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 230,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = Curves.easeOutCubic.transform(_controller.value);
          final total = widget.slices.fold<int>(
            0,
            (sum, slice) => sum + slice.amount,
          );
          return CustomPaint(
            painter: _RingPainter(widget.slices, progress),
            child: Center(
              child: Text(
                formatCompact((total * progress).round()),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

bool _hasAmount(List<SpendingSlice> slices) {
  return slices.any((slice) => slice.amount > 0);
}

bool _sameSlices(List<SpendingSlice> left, List<SpendingSlice> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].name != right[index].name ||
        left[index].amount != right[index].amount) {
      return false;
    }
  }
  return true;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.slices, this.progress);

  final List<SpendingSlice> slices;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final radius = size.width / 2 - stroke / 2 - 4;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = const Color(0xFF3A3A3C),
    );

    final visible = slices.where((slice) => slice.amount > 0).toList();
    if (visible.isEmpty || progress <= 0) return;

    final total = visible.fold<int>(0, (sum, slice) => sum + slice.amount);
    final cap = stroke / (2 * radius);
    var gap = cap * 2.6;
    if (gap * visible.length > math.pi) {
      gap = math.pi / visible.length;
    }
    final available = math.pi * 2 - gap * visible.length;
    var start = -math.pi / 2 + gap / 2;
    for (final slice in visible) {
      final sweep = available * (slice.amount / total) * progress;
      if (sweep <= 0) continue;
      canvas.drawArc(rect, start, sweep, false, paint..color = slice.color);
      start += available * (slice.amount / total) + gap;
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.slices != slices;
  }
}
