import 'dart:math' as math;

import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/celebration.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _red = Color(0xFFFF6B6B);

const goalIconKeys = [
  'goal-target',
  'travel',
  'goal-phone',
  'goal-bike',
  'goal-car',
  'home',
  'goal-wedding',
  'goal-emergency',
  'education',
  'kids',
  'gifts',
  'freelance',
  'investments',
  'shopping',
  'health',
  'pets',
  'entertainment',
];

class GoalsStrip extends StatelessWidget {
  const GoalsStrip({super.key, required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final goals = ledger.goals;
    final saved = goals.fold<int>(0, (sum, goal) => sum + goal.saved);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Goals',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                saved > 0 ? '${formatRupees(saved)} saved' : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 14),
              ),
            ),
            TextButton.icon(
              onPressed: () => showGoalEditor(context, ledger: ledger),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('New goal'),
              style: TextButton.styleFrom(foregroundColor: _lime),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (goals.isEmpty)
          _EmptyGoal(onTap: () => showGoalEditor(context, ledger: ledger))
        else if (goals.length <= 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, goal) in goals.indexed) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _GoalCard(
                      goal: goal,
                      onTap: () =>
                          showGoalSheet(context, ledger: ledger, goal: goal),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, goal) in goals.indexed) ...[
                    if (index > 0) const SizedBox(width: 12),
                    SizedBox(
                      width: 158,
                      child: _GoalCard(
                        goal: goal,
                        onTap: () =>
                            showGoalSheet(context, ledger: ledger, goal: goal),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GoalRing(goal: goal, size: 92),
                const SizedBox(height: 10),
                Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  goal.reached
                      ? 'Reached!'
                      : '${formatCompact(goal.saved)} of ${formatCompact(goal.targetAmount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: goal.reached ? _lime : _muted,
                    fontSize: 13,
                    fontWeight: goal.reached ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyGoal extends StatelessWidget {
  const _EmptyGoal({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
            child: Row(
              children: [
                const CategoryIcon.key('goal-target', size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Save for something',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'A trip, a new phone, an emergency fund. Then just say "add 500 to Goa trip".',
                        style: TextStyle(color: _muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoalRing extends StatelessWidget {
  const GoalRing({super.key, required this.goal, this.size = 92});

  final Goal goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: goal.progress),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => CustomPaint(
        painter: _RingPainter(
          value,
          goal.reached ? _lime : const Color(0xFF7EC8E3),
        ),
        child: child,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: CategoryIcon.key(
            goal.icon ?? 'goal-target',
            size: size * 0.52,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.08;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - stroke / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = _line);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

Future<void> showGoalSheet(
  BuildContext context, {
  required Ledger ledger,
  required Goal goal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _GoalSheet(ledger: ledger, goalId: goal.id),
  );
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.ledger, required this.goalId});

  final Ledger ledger;
  final String goalId;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  List<GoalEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.ledger.goalEntries(widget.goalId);
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      if (mounted) setState(() => _entries = const []);
    }
  }

  Goal? get _goal =>
      widget.ledger.goals.where((goal) => goal.id == widget.goalId).firstOrNull;

  Future<void> _money(Goal goal, String type) async {
    final changed = await showGoalMoney(
      context,
      ledger: widget.ledger,
      goal: goal,
      type: type,
    );
    if (changed) await _load();
  }

  Future<void> _delete(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text('Delete ${goal.name}?'),
        content: const Text(
          'The goal and its history are removed. Your account balances do not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.ledger.deleteGoal(goal.id);
      if (mounted) Navigator.of(context).pop();
    } on FinanceException catch (caught) {
      if (mounted) _snack(context, caught.message);
    }
  }

  Future<void> _deleteEntry(GoalEntry entry) async {
    try {
      await widget.ledger.deleteGoalEntry(entry.id);
      await _load();
    } on FinanceException catch (caught) {
      if (mounted) _snack(context, caught.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ledger,
      builder: (context, _) {
        final goal = _goal;
        if (goal == null) return const SizedBox(height: 200);
        final monthly = goal.monthlyNeeded(DateTime.now());
        final entries = _entries;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              const _Handle(),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Edit goal',
                  onPressed: () => showGoalEditor(
                    context,
                    ledger: widget.ledger,
                    existing: goal,
                  ),
                  icon: const Icon(LucideIcons.pencil, color: _muted, size: 20),
                ),
              ),
              Center(child: GoalRing(goal: goal, size: 160)),
              const SizedBox(height: 14),
              Text(
                goal.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatRupees(goal.saved)} of ${formatRupees(goal.targetAmount)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                goal.reached
                    ? 'Goal reached!'
                    : [
                        '${formatRupees(goal.left)} to go',
                        if (goal.targetDate != null)
                          'by ${formatDate(goal.targetDate!)}',
                        if (monthly != null) '${formatRupees(monthly)} a month',
                      ].join(' · '),
                textAlign: TextAlign.center,
                style: TextStyle(color: goal.reached ? _lime : _muted),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _money(goal, 'add'),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('Add money'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: goal.saved > 0
                          ? () => _money(goal, 'take_out')
                          : null,
                      icon: const Icon(LucideIcons.minus, size: 18),
                      label: const Text('Take out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _line),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'The money stays in your accounts. Goals only keep it aside in your head.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              const Text(
                'HISTORY',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              if (entries == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Nothing added yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                )
              else
                for (final entry in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      entry.amount > 0
                          ? LucideIcons.arrowDownLeft
                          : LucideIcons.arrowUpRight,
                      color: entry.amount > 0 ? _lime : Colors.white,
                    ),
                    title: Text(
                      entry.amount > 0 ? 'Added' : 'Taken out',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      [
                        formatDate(entry.occurredOn),
                        if (entry.note != null && entry.note!.isNotEmpty)
                          entry.note!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${entry.amount > 0 ? '+' : '-'}${formatRupees(entry.amount.abs())}',
                          style: TextStyle(
                            color: entry.amount > 0 ? _lime : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _deleteEntry(entry),
                          icon: const Icon(
                            LucideIcons.trash2,
                            color: _muted,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _delete(goal),
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text('Delete goal'),
                style: TextButton.styleFrom(foregroundColor: _red),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Returns true when money was added or taken out.
Future<bool> showGoalMoney(
  BuildContext context, {
  required Ledger ledger,
  required Goal goal,
  required String type,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) =>
        _GoalMoneySheet(ledger: ledger, goal: goal, type: type),
  );
  return changed == true;
}

class _GoalMoneySheet extends StatefulWidget {
  const _GoalMoneySheet({
    required this.ledger,
    required this.goal,
    required this.type,
  });

  final Ledger ledger;
  final Goal goal;
  final String type;

  @override
  State<_GoalMoneySheet> createState() => _GoalMoneySheetState();
}

class _GoalMoneySheetState extends State<_GoalMoneySheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  var _busy = false;
  String? _error;

  bool get _adding => widget.type == 'add';

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text.replaceAll(',', ''));
    if (amount == null) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (!_adding && amount > widget.goal.saved) {
      setState(
        () => _error = 'Only ${formatRupees(widget.goal.saved)} is saved here',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final goal = await widget.ledger.addGoalEntry(
        goalId: widget.goal.id,
        type: widget.type,
        amount: amount,
        note: _note.text,
      );
      if (_adding && goal.reached && !widget.goal.reached) Celebration.play();
      if (mounted) Navigator.of(context).pop(true);
    } on FinanceException catch (caught) {
      if (mounted) setState(() => _error = caught.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final quick = _adding
        ? [50000, 100000, 200000, if (goal.left > 0) goal.left]
        : [if (goal.saved > 0) goal.saved];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Handle(),
            const SizedBox(height: 16),
            Row(
              children: [
                CategoryIcon.key(goal.icon ?? 'goal-target', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _adding
                        ? 'Add to ${goal.name}'
                        : 'Take out of ${goal.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Input(
              controller: _amount,
              hint: 'Amount',
              icon: LucideIcons.indianRupee,
              number: true,
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in quick.toSet())
                  ActionChip(
                    label: Text(
                      value == goal.left && _adding
                          ? 'Rest ${formatRupees(value)}'
                          : value == goal.saved && !_adding
                          ? 'All ${formatRupees(value)}'
                          : formatRupees(value),
                    ),
                    onPressed: () => _amount.text = value % 100 == 0
                        ? '${value ~/ 100}'
                        : (value / 100).toStringAsFixed(2),
                    backgroundColor: _card,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(color: Colors.white),
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Input(
              controller: _note,
              hint: _adding
                  ? 'Note (optional), e.g. bonus'
                  : 'What for? (optional)',
              icon: LucideIcons.notebookPen,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _red),
                ),
              ),
            const SizedBox(height: 18),
            _SaveButton(
              label: _adding ? 'Add money' : 'Take out',
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showGoalEditor(
  BuildContext context, {
  required Ledger ledger,
  Goal? existing,
}) async {
  await ledger.loadCategoryIcons();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => GoalEditor(ledger: ledger, existing: existing),
  );
}

class GoalEditor extends StatefulWidget {
  const GoalEditor({super.key, required this.ledger, this.existing});

  final Ledger ledger;
  final Goal? existing;

  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _target = TextEditingController(
    text: switch (widget.existing?.targetAmount) {
      null => '',
      final paise when paise % 100 == 0 => '${paise ~/ 100}',
      final paise => (paise / 100).toStringAsFixed(2),
    },
  );
  late String _icon = widget.existing?.icon ?? 'goal-target';
  late DateTime? _date = DateTime.tryParse(widget.existing?.targetDate ?? '');
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(now.year, now.month + 6, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = parseMoney(_target.text.replaceAll(',', ''));
    if (name.isEmpty) {
      setState(() => _error = 'What are you saving for?');
      return;
    }
    if (target == null) {
      setState(() => _error = 'How much do you need?');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.ledger.saveGoal(
        id: widget.existing?.id,
        name: name,
        icon: _icon,
        targetAmount: target,
        targetDate: _date == null ? null : isoDate(_date!),
      );
      if (mounted) Navigator.of(context).pop();
    } on FinanceException catch (caught) {
      if (mounted) setState(() => _error = caught.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Handle(),
            const SizedBox(height: 16),
            Row(
              children: [
                CategoryIcon.key(_icon, size: 52),
                const SizedBox(width: 12),
                Text(
                  editing ? 'Edit goal' : 'New goal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Input(
              controller: _name,
              hint: 'Saving for? e.g. Goa trip',
              icon: LucideIcons.target,
              autofocus: !editing,
              capitalize: true,
            ),
            const SizedBox(height: 12),
            _Input(
              controller: _target,
              hint: 'Target amount',
              icon: LucideIcons.indianRupee,
              number: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ActionChip(
                  avatar: const Icon(
                    LucideIcons.calendar,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    _date == null
                        ? 'Add a target date'
                        : 'By ${formatDate(isoDate(_date!))}',
                  ),
                  onPressed: _busy ? null : _pickDate,
                  backgroundColor: _field,
                  side: const BorderSide(color: _line),
                  labelStyle: const TextStyle(color: Colors.white),
                  shape: const StadiumBorder(),
                ),
                if (_date != null)
                  IconButton(
                    tooltip: 'No date',
                    onPressed: () => setState(() => _date = null),
                    icon: const Icon(LucideIcons.x, color: _muted, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Icon',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final icon in goalIconKeys)
                  Semantics(
                    button: true,
                    selected: icon == _icon,
                    label: icon,
                    child: GestureDetector(
                      onTap: () => setState(() => _icon = icon),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: icon == _icon ? _lime : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: FittedBox(child: CategoryIcon.key(icon)),
                      ),
                    ),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _red),
                ),
              ),
            const SizedBox(height: 20),
            _SaveButton(
              label: editing ? 'Save changes' : 'Create goal',
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: _line,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    required this.icon,
    this.number = false,
    this.capitalize = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool number;
  final bool capitalize;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textCapitalization: capitalize
          ? TextCapitalization.words
          : TextCapitalization.sentences,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF5C5C60)),
        prefixIcon: Icon(icon, color: _muted, size: 20),
        filled: true,
        fillColor: _field,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: _line,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
