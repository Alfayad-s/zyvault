import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _orange = Color(0xFFFFB35C);

final _questionStart = RegExp(
  r'^(how|what|whats|where|who|whom|which|when|why|show|list|tell|did|do|does|am|is|are|was|were|have|has|can|total|kitna|kitne|kitni|kya|kaha|ethra|ethrayanu|evide|enthu|entha|aarokke|aaru)\b',
);
final _questionWords = RegExp(
  r'\b(ethra|kitna|kitne|evide|how much|how many)\b',
);

bool looksLikeQuestion(String text) {
  final lower = text.trim().toLowerCase();
  if (lower.isEmpty) return false;
  if (lower.endsWith('?')) return true;
  if (_questionStart.hasMatch(lower)) return true;
  if (lower.contains('എത്ര') ||
      lower.contains('എവിടെ') ||
      lower.contains('ആര്')) {
    return true;
  }
  return _questionWords.hasMatch(lower);
}

Future<void> showAskAnswer(
  BuildContext context, {
  required String question,
  required AskAnswer answer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: answer.chart.isEmpty && answer.items.length < 4
          ? 0.5
          : 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => AskAnswerView(
        question: question,
        answer: answer,
        controller: controller,
      ),
    ),
  );
}

class AskAnswerView extends StatelessWidget {
  const AskAnswerView({
    super.key,
    required this.question,
    required this.answer,
    this.controller,
  });

  final String question;
  final AskAnswer answer;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final byCategory = answer.chart.any((point) => point.categoryName != null);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              LucideIcons.messageCircleQuestion,
              color: _muted,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question,
                style: const TextStyle(color: _muted, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          answer.answer,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        if (answer.chart.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: byCategory
                ? _CategoryBars(points: answer.chart)
                : _TimeBars(points: answer.chart),
          ),
        ],
        if (answer.items.isNotEmpty && !byCategory) ...[
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                for (final (index, item) in answer.items.indexed) ...[
                  if (index > 0) const Divider(height: 1, color: _line),
                  _ItemRow(item: item, intent: answer.intent),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.intent});

  final AskItem item;
  final String intent;

  @override
  Widget build(BuildContext context) {
    final icon = item.iconKey != null
        ? CategoryIcon.key(item.iconKey!, size: 38)
        : item.categoryName != null
        ? CategoryIcon(
            name: item.categoryName!,
            kind: item.kind ?? 'expense',
            size: 38,
          )
        : const SizedBox(
            width: 38,
            height: 38,
            child: Icon(LucideIcons.wallet, color: Colors.white),
          );
    final color = intent == 'people'
        ? item.value > 0
              ? _lime
              : item.value < 0
              ? _orange
              : _muted
        : item.kind == 'income'
        ? _lime
        : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.detail != null)
                  Text(
                    item.detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${item.value < 0 && intent == 'balance' ? '-' : ''}${formatRupees(item.value.abs())}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.points});

  final List<AskPoint> points;

  @override
  Widget build(BuildContext context) {
    final top = points.fold<int>(
      1,
      (max, point) => point.value > max ? point.value : max,
    );
    return Column(
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CategoryIcon(
                  name: point.categoryName ?? point.label,
                  kind: point.kind ?? 'expense',
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              point.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            formatRupees(point.value),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: point.value / top),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 8,
                                backgroundColor: _line,
                                color: _lime,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimeBars extends StatelessWidget {
  const _TimeBars({required this.points});

  final List<AskPoint> points;

  @override
  Widget build(BuildContext context) {
    final top = points.fold<int>(
      1,
      (max, point) => point.value > max ? point.value : max,
    );
    final gap = points.length > 20 ? 2.0 : 4.0;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Highest ${formatCompact(top)}',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final point in points)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: gap / 2),
                    child: Tooltip(
                      message: '${point.label}: ${formatRupees(point.value)}',
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: point.value / top),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Container(
                          height: point.value == 0 ? 3 : 4 + 116 * value,
                          decoration: BoxDecoration(
                            color: point.value == 0 ? _line : _lime,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              points.first.label,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const Spacer(),
            if (points.length > 2)
              Text(
                points[points.length ~/ 2].label,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            const Spacer(),
            Text(
              points.last.label,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
