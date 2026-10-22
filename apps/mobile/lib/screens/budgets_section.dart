import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:finance_track/widgets/pull_refresh.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _orange = Color(0xFFFFB35C);
const _red = Color(0xFFFF6B6B);

const warnAt = 0.8;

Color budgetColor(Budget budget) => budget.over
    ? _red
    : budget.used >= warnAt
    ? _orange
    : _lime;

String budgetStatus(Budget budget) {
  if (budget.over) return 'Over by ${formatRupees(-budget.left)}';
  return '${formatRupees(budget.left)} left';
}

/// Lines to add after a save when a category is close to or past its limit.
List<String> budgetWarnings(Ledger ledger, Iterable<String> categoryNames) {
  final lines = <String>[];
  for (final name in categoryNames.toSet()) {
    final budget = ledger.budgetFor(name);
    if (budget == null || budget.used < warnAt) continue;
    lines.add(
      budget.over
          ? '${budget.categoryName} budget: over by ${formatRupees(-budget.left)}'
          : '${budget.categoryName} budget: ${(budget.used * 100).round()}% used',
    );
  }
  return lines;
}

class BudgetsCard extends StatelessWidget {
  const BudgetsCard({super.key, required this.ledger});

  final Ledger ledger;

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => BudgetsScreen(ledger: ledger)),
  );

  @override
  Widget build(BuildContext context) {
    final budgets = [...ledger.budgets]
      ..sort((a, b) => b.used.compareTo(a.used));
    final limit = budgets.fold<int>(
      0,
      (sum, budget) => sum + budget.limitAmount,
    );
    final spent = budgets.fold<int>(0, (sum, budget) => sum + budget.spent);
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Budgets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      budgets.isEmpty
                          ? ''
                          : limit - spent >= 0
                          ? '${formatRupees(limit - spent)} left'
                          : '${formatRupees(spent - limit)} over',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: limit - spent >= 0 ? _muted : _red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    budgets.isEmpty ? 'Set up' : 'Manage',
                    style: const TextStyle(color: _muted, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (budgets.isEmpty)
                const Row(
                  children: [
                    CategoryIcon.key('investments', size: 48),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Set a monthly limit for food, shopping or anything else. I will warn you at 80%.',
                        style: TextStyle(color: _muted, height: 1.35),
                      ),
                    ),
                  ],
                )
              else
                for (final budget in budgets.take(4))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: BudgetRow(budget: budget),
                  ),
              if (budgets.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${budgets.length - 4} more',
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BudgetRow extends StatelessWidget {
  const BudgetRow({super.key, required this.budget, this.onTap});

  final Budget budget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = budgetColor(budget);
    final row = Row(
      children: [
        CategoryIcon(name: budget.categoryName, kind: 'expense', size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      budget.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    budgetStatus(budget),
                    style: TextStyle(
                      color: budget.over || budget.used >= warnAt
                          ? color
                          : _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: budget.used.clamp(0, 1).toDouble(),
                  ),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: _line,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatRupees(budget.spent)} of ${formatRupees(budget.limitAmount)}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: row,
      ),
    );
  }
}

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key, required this.ledger});

  final Ledger ledger;

  Future<void> _edit(BuildContext context, {Budget? existing}) async {
    final budgeted = {for (final budget in ledger.budgets) budget.categoryId};
    final categories = ledger.categories
        .where(
          (category) =>
              category.kind == 'expense' &&
              (existing != null || !budgeted.contains(category.id)),
        )
        .toList();
    if (existing == null && categories.isEmpty) {
      _snack(context, 'Every category already has a budget');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => BudgetEditor(
        ledger: ledger,
        categories: categories,
        existing: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Budgets · ${monthLabel(ledger.month)}')),
      body: ListenableBuilder(
        listenable: ledger,
        builder: (context, _) {
          final budgets = [...ledger.budgets]
            ..sort((a, b) => b.used.compareTo(a.used));
          final limit = budgets.fold<int>(
            0,
            (sum, budget) => sum + budget.limitAmount,
          );
          final spent = budgets.fold<int>(
            0,
            (sum, budget) => sum + budget.spent,
          );
          return PullRefresh(
            onRefresh: ledger.refresh,
            child: ListView(
            physics: pullPhysics,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              if (budgets.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spent of all budgets',
                        style: TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatRupees(spent)} of ${formatRupees(limit)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: limit == 0
                              ? 0
                              : (spent / limit).clamp(0, 1).toDouble(),
                          minHeight: 10,
                          backgroundColor: _line,
                          color: spent > limit
                              ? _red
                              : limit > 0 && spent / limit >= warnAt
                              ? _orange
                              : _lime,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Limits carry over to next month by themselves.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (budgets.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      for (final (index, budget) in budgets.indexed) ...[
                        if (index > 0) const Divider(height: 1, color: _line),
                        BudgetRow(
                          budget: budget,
                          onTap: () => _edit(context, existing: budget),
                        ),
                      ],
                    ],
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 48, 24, 24),
                  child: Column(
                    children: [
                      CategoryIcon.key('investments', size: 72),
                      SizedBox(height: 16),
                      Text(
                        'No budgets yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pick a category and a monthly limit. You will see a warning when you reach 80%.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Add budget'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            ),
          );
        },
      ),
    );
  }
}

class BudgetEditor extends StatefulWidget {
  const BudgetEditor({
    super.key,
    required this.ledger,
    required this.categories,
    this.existing,
  });

  final Ledger ledger;
  final List<Category> categories;
  final Budget? existing;

  @override
  State<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<BudgetEditor> {
  late String? _categoryId =
      widget.existing?.categoryId ??
      (widget.categories.isEmpty ? null : widget.categories.first.id);
  late final _amount = TextEditingController(
    text: switch (widget.existing?.limitAmount) {
      null => '',
      final paise when paise % 100 == 0 => '${paise ~/ 100}',
      final paise => (paise / 100).toStringAsFixed(2),
    },
  );
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final categoryId = _categoryId;
    final amount = parseMoney(_amount.text.replaceAll(',', ''));
    if (categoryId == null) {
      setState(() => _error = 'Pick a category');
      return;
    }
    if (amount == null) {
      setState(() => _error = 'Enter a monthly limit');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.ledger.saveBudget(
        categoryId: categoryId,
        limitAmount: amount,
      );
      if (mounted) Navigator.of(context).pop();
    } on FinanceException catch (caught) {
      if (mounted) setState(() => _error = caught.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    setState(() => _busy = true);
    try {
      await widget.ledger.deleteBudget(existing.id);
      if (mounted) Navigator.of(context).pop();
    } on FinanceException catch (caught) {
      if (mounted) setState(() => _error = caught.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            Text(
              existing == null
                  ? 'New budget'
                  : '${existing.categoryName} budget',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (existing == null) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = widget.categories[index];
                    final selected = category.id == _categoryId;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: category.name,
                      child: GestureDetector(
                        onTap: () => setState(() => _categoryId = category.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 82,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: selected
                                ? _lime.withValues(alpha: 0.14)
                                : _card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected ? _lime : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CategoryIcon(
                                name: category.name,
                                kind: 'expense',
                                size: 38,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              autofocus: existing != null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Monthly limit',
                hintStyle: const TextStyle(color: Color(0xFF5C5C60)),
                prefixIcon: const Icon(
                  LucideIcons.indianRupee,
                  color: _muted,
                  size: 20,
                ),
                filled: true,
                fillColor: _field,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
            if (existing != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Spent ${formatRupees(existing.spent)} so far this month',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
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
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: _line,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(existing == null ? 'Set budget' : 'Save'),
              ),
            ),
            if (existing != null)
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text('Remove budget'),
                style: TextButton.styleFrom(foregroundColor: _red),
              ),
          ],
        ),
      ),
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
