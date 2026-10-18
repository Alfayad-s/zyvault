import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/account_chip.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _green = Color(0xFF3DDC84);

const _reviewKey = 'review_before_save';

Future<bool> loadReviewBeforeSave() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_reviewKey) ?? true;
  } catch (_) {
    return true;
  }
}

Future<void> saveReviewBeforeSave(bool value) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_reviewKey, value);
  } catch (_) {}
}

/// Shows what the AI understood and returns the entries to save, or null.
Future<List<ParsedSpend>?> reviewSpends(
  BuildContext context, {
  required Ledger ledger,
  required String sentence,
  required List<ParsedSpend> drafts,
  required String defaultAccountId,
}) {
  return showModalBottomSheet<List<ParsedSpend>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => ReviewSheet(
      ledger: ledger,
      sentence: sentence,
      drafts: drafts,
      defaultAccountId: defaultAccountId,
    ),
  );
}

class ReviewSheet extends StatefulWidget {
  const ReviewSheet({
    super.key,
    required this.ledger,
    required this.sentence,
    required this.drafts,
    required this.defaultAccountId,
  });

  final Ledger ledger;
  final String sentence;
  final List<ParsedSpend> drafts;
  final String defaultAccountId;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late final List<ParsedSpend> _items = [
    for (final draft in widget.drafts)
      draft.accountId == null
          ? draft.copyWith(accountId: widget.defaultAccountId)
          : draft,
  ];

  Ledger get _ledger => widget.ledger;

  void _replace(int index, ParsedSpend next) =>
      setState(() => _items[index] = next);

  Account? _account(ParsedSpend item) => _ledger.accounts
      .where((account) => account.id == item.accountId)
      .firstOrNull;

  Future<void> _editAmount(int index) async {
    final item = _items[index];
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => _AmountDialog(amount: item.amount),
    );
    if (amount != null && mounted) {
      _replace(index, item.copyWith(amount: amount));
    }
  }

  Future<void> _editCategory(int index) async {
    final item = _items[index];
    final picked = await showModalBottomSheet<Category>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CategoryPicker(
        categories: _ledger.categories
            .where((category) => category.kind == item.kind)
            .toList(),
        selectedId: item.categoryId,
      ),
    );
    if (picked != null && mounted) {
      _replace(
        index,
        item.copyWith(categoryId: picked.id, categoryName: picked.name),
      );
    }
  }

  void _flipKind(int index) {
    final item = _items[index];
    final kind = item.kind == 'income' ? 'expense' : 'income';
    final sameKind = _ledger.categories.where(
      (category) => category.kind == kind,
    );
    final category =
        sameKind
            .where(
              (category) =>
                  category.name.toLowerCase() ==
                  item.categoryName.toLowerCase(),
            )
            .firstOrNull ??
        sameKind
            .where(
              (category) =>
                  category.name.toLowerCase() ==
                  (kind == 'income' ? 'other income' : 'other'),
            )
            .firstOrNull ??
        sameKind.firstOrNull;
    if (category == null) return;
    _replace(
      index,
      item.copyWith(
        kind: kind,
        categoryId: category.id,
        categoryName: category.name,
      ),
    );
  }

  Future<void> _editAccount(int index) async {
    final item = _items[index];
    final picked = await showAccountPicker(
      context,
      accounts: _ledger.accounts,
      bankFor: _ledger.bankFor,
      currentId: item.accountId,
      title: item.kind == 'income' ? 'Received in' : 'Paid from',
    );
    if (picked != null && mounted) {
      _replace(
        index,
        item.copyWith(accountId: picked.id, accountName: picked.name),
      );
    }
  }

  Future<void> _editDate(int index) async {
    final item = _items[index];
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(item.occurredOn) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null && mounted) {
      _replace(index, item.copyWith(occurredOn: isoDate(picked)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: total > 1 ? 0.8 : 0.62,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
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
                    total == 1 ? 'Is this right?' : 'I found $total entries',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '“${widget.sentence}”',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Nothing left to save',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  for (final (index, item) in _items.indexed) ...[
                    _ReviewCard(
                      item: item,
                      account: _account(item),
                      bank: _account(item) == null
                          ? null
                          : _ledger.bankFor(_account(item)!),
                      onAmount: () => _editAmount(index),
                      onCategory: () => _editCategory(index),
                      onKind: () => _flipKind(index),
                      onAccount: () => _editAccount(index),
                      onDate: () => _editDate(index),
                      onNote: (note) =>
                          _items[index] = _items[index].copyWith(note: note),
                      onRemove: () => setState(() => _items.removeAt(index)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _line),
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _items.isEmpty
                            ? null
                            : () =>
                                  Navigator.of(context)
                                      .pop(List<ParsedSpend>.of(_items)),
                        icon: const Icon(LucideIcons.send, size: 18),
                        label: Text(total > 1 ? 'Save all $total' : 'Save'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: _line,
                          minimumSize: const Size.fromHeight(56),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

String? reviewBadge(ParsedSpend item) {
  final schedule = item.schedule;
  if (schedule != null) {
    final at = schedule.atTime == null
        ? ''
        : ' at ${formatClock(schedule.atTime!)}';
    if (schedule.monthly) {
      return 'Every month on the ${_ordinal(schedule.dayOfMonth)}$at';
    }
    final day = schedule.nextOn == isoDate(DateTime.now())
        ? 'today'
        : formatDate(schedule.nextOn);
    return 'Planned for $day$at';
  }
  final debt = item.debt;
  if (debt != null) {
    return switch (debt.type) {
      'lent' => 'Lent to ${debt.person}',
      'borrowed' => 'Borrowed from ${debt.person}',
      'got_back' => '${debt.person} paid you back',
      _ => 'Paid back ${debt.person}',
    };
  }
  final goal = item.goal;
  if (goal != null) {
    return goal.action == 'add'
        ? 'Add to ${goal.name}'
        : 'Take out of ${goal.name}';
  }
  return null;
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({
    required this.item,
    required this.account,
    required this.bank,
    required this.onAmount,
    required this.onCategory,
    required this.onKind,
    required this.onAccount,
    required this.onDate,
    required this.onNote,
    required this.onRemove,
  });

  final ParsedSpend item;
  final Account? account;
  final Bank? bank;
  final VoidCallback onAmount;
  final VoidCallback onCategory;
  final VoidCallback onKind;
  final VoidCallback onAccount;
  final VoidCallback onDate;
  final ValueChanged<String> onNote;
  final VoidCallback onRemove;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  late final _note = TextEditingController(text: widget.item.note);

  @override
  void didUpdateWidget(_ReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.note != _note.text &&
        oldWidget.item.note != widget.item.note) {
      _note.text = widget.item.note;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final income = item.kind == 'income';
    final badge = reviewBadge(item);
    final plain = item.debt == null && item.goal == null;
    final iconKey = item.goal != null
        ? 'goal-target'
        : item.debt != null
        ? (income ? 'borrowed' : 'lent')
        : null;
    final today = isoDate(DateTime.now());
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconKey != null
                  ? CategoryIcon.key(iconKey, size: 44)
                  : CategoryIcon(
                      name: item.categoryName,
                      kind: item.kind,
                      size: 44,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Change amount',
                      child: GestureDetector(
                        onTap: widget.onAmount,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '${income ? '+' : ''}${formatRupees(item.amount)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: income ? _green : Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              LucideIcons.pencil,
                              color: _muted,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (badge != null)
                      Text(
                        badge,
                        style: const TextStyle(
                          color: _lime,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: widget.onRemove,
                icon: const Icon(LucideIcons.x, color: _muted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (plain)
                  _Chip(
                    label: income ? 'Received' : 'Spent',
                    icon: income
                        ? LucideIcons.arrowDownLeft
                        : LucideIcons.arrowUpRight,
                    onTap: widget.onKind,
                  ),
                if (plain)
                  _Chip(
                    label: item.categoryName,
                    leading: CategoryIcon(
                      name: item.categoryName,
                      kind: item.kind,
                      size: 22,
                    ),
                    onTap: widget.onCategory,
                  ),
                if (widget.account != null && item.goal == null)
                  AccountChip(
                    account: widget.account!,
                    bank: widget.bank,
                    onTap: widget.onAccount,
                    maxNameWidth: 110,
                    verb: income ? 'Received in' : 'Paid from',
                  ),
                if (item.schedule == null)
                  _Chip(
                    label: item.occurredOn == today
                        ? 'Today'
                        : formatDate(item.occurredOn),
                    icon: LucideIcons.calendar,
                    onTap: widget.onDate,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              controller: _note,
              onChanged: widget.onNote,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Note',
                hintStyle: const TextStyle(color: Color(0xFF5C5C60)),
                prefixIcon: const Icon(
                  LucideIcons.notebookPen,
                  color: _muted,
                  size: 18,
                ),
                filled: true,
                fillColor: _field,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _field,
      shape: const StadiumBorder(side: BorderSide(color: _line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(leading != null ? 6 : 10, 6, 12, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?leading,
              if (icon != null) Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.categories, required this.selectedId});

  final List<Category> categories;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => GridView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 96,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category.id == selectedId;
          return Material(
            color: selected ? _lime.withValues(alpha: 0.14) : _card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: selected ? _lime : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context).pop(category),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CategoryIcon(
                    name: category.name,
                    kind: category.kind,
                    size: 40,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      category.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.amount});

  final int amount;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final _controller = TextEditingController(
    text: widget.amount % 100 == 0
        ? '${widget.amount ~/ 100}'
        : (widget.amount / 100).toStringAsFixed(2),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() =>
      Navigator.pop(context, parseMoney(_controller.text.replaceAll(',', '')));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: const Text('Amount'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(prefixText: '₹ '),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _done, child: const Text('Done')),
      ],
    );
  }
}
