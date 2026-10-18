import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/account_chip.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _green = Color(0xFF3DDC84);
const _red = Color(0xFFFF6B6B);

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    required this.ledger,
    this.existing,
    this.initialKind,
  });

  final Ledger ledger;
  final TransactionItem? existing;
  final String? initialKind;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _kind;
  late DateTime _date;
  String? _accountId;
  String? _categoryId;
  var _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amount = TextEditingController(
      text: existing == null ? '' : _amountText(existing.amount),
    );
    _note = TextEditingController(text: existing?.note ?? '');
    _kind = existing?.kind ?? widget.initialKind ?? 'expense';
    _categoryId = existing?.categoryId;
    _accountId = existing?.accountId ?? _defaultAccount()?.id;
    _date = existing == null ? _today() : DateTime.parse(existing.occurredOn);
    if (existing == null) _useSavedDefault();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _amountText(int paise) {
    return paise % 100 == 0
        ? '${paise ~/ 100}'
        : (paise / 100).toStringAsFixed(2);
  }

  Account? _defaultAccount() {
    final accounts = widget.ledger.accounts;
    for (final account in accounts) {
      if (account.type == 'cash') return account;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  Account? get _selectedAccount {
    for (final account in widget.ledger.accounts) {
      if (account.id == _accountId) return account;
    }
    return null;
  }

  Future<void> _useSavedDefault() async {
    final saved = await loadDefaultAccountId();
    if (!mounted || saved == null || _editing) return;
    if (widget.ledger.accounts.any((account) => account.id == saved)) {
      setState(() => _accountId = saved);
    }
  }

  Future<void> _chooseAccount() async {
    final picked = await showAccountPicker(
      context,
      accounts: widget.ledger.accounts,
      bankFor: widget.ledger.bankFor,
      currentId: _accountId,
      title: _kind == 'income' ? 'Receive in' : 'Pay from',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _accountId = picked.id;
      _error = null;
    });
    await saveDefaultAccountId(picked.id);
  }

  List<Category> get _categories => widget.ledger.categories
      .where((category) => category.kind == _kind)
      .toList();

  void _setKind(String kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _categoryId = null;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text.replaceAll(',', ''));
    final accountId = _accountId;
    final categoryId = _categoryId;
    final problem = amount == null
        ? 'Enter an amount'
        : categoryId == null
        ? 'Pick a category'
        : accountId == null
        ? 'Pick an account'
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.ledger.saveTransaction(
        id: widget.existing?.id,
        accountId: accountId!,
        categoryId: categoryId!,
        amount: amount!,
        kind: _kind,
        occurredOn: isoDate(_date),
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } on FinanceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the transaction');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete this transaction?'),
        content: const Text(
          'It will be removed from your history and balances.',
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
    setState(() => _busy = true);
    try {
      await widget.ledger.deleteTransaction(id);
      if (mounted) Navigator.of(context).pop();
    } on FinanceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.ledger.accounts;
    final income = _kind == 'income';
    final title = _editing
        ? 'Edit transaction'
        : income
        ? 'Add income'
        : 'Add expense';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(LucideIcons.x),
        ),
        title: Text(title),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              onPressed: _busy ? null : _delete,
              icon: const Icon(LucideIcons.trash2, color: _red),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _selectedAccount == null
                      ? const Text(
                          'Add an account on the Money page first',
                          style: TextStyle(color: _muted, fontSize: 13),
                        )
                      : AccountChip(
                          account: _selectedAccount!,
                          bank: widget.ledger.bankFor(_selectedAccount!),
                          onTap: _busy ? null : _chooseAccount,
                          maxNameWidth: 110,
                          verb: income ? 'Receiving in' : 'Paying from',
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _KindSwitch(kind: _kind, onChanged: _setKind),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _AmountField(
            controller: _amount,
            income: income,
            autofocus: !_editing,
          ),
          const SizedBox(height: 32),
          const _Label('Category'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final category in _categories)
                _CategoryChip(
                  category: category,
                  selected: category.id == _categoryId,
                  onTap: () => setState(() {
                    _categoryId = category.id;
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 28),
          const _Label('Date'),
          const SizedBox(height: 12),
          _DatePicker(
            date: _date,
            onChanged: (date) => setState(() => _date = date),
            onPick: _pickDate,
          ),
          const SizedBox(height: 28),
          const _Label('Note'),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: income
                  ? 'Salary, refund, gift…'
                  : 'Pizza with friends…',
              hintStyle: const TextStyle(color: Color(0xFF5C5C60)),
              prefixIcon: const Icon(
                LucideIcons.notebookPen,
                color: _muted,
                size: 20,
              ),
              filled: true,
              fillColor: _field,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _red, fontSize: 14),
                  ),
                ),
              SizedBox(
                height: 58,
                child: FilledButton(
                  onPressed: _busy || accounts.isEmpty ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: _line,
                    disabledForegroundColor: _muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(_editing ? 'Save changes' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.kind, required this.onChanged});

  final String kind;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String value, String label) {
      final selected = kind == value;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _line : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('expense', 'Expense'), option('income', 'Income')],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.income,
    required this.autofocus,
  });

  final TextEditingController controller;
  final bool income;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final color = income ? _green : Colors.white;
    return Column(
      children: [
        IntrinsicWidth(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            cursorColor: color,
            style: TextStyle(
              color: color,
              fontSize: 52,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
              hintText: '0',
              hintStyle: const TextStyle(
                color: Color(0xFF5C5C60),
                fontSize: 52,
                fontWeight: FontWeight.w800,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          income ? 'Money in' : 'Money out',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          decoration: BoxDecoration(
            color: selected ? _lime.withValues(alpha: 0.12) : _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? _lime : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryIcon(name: category.name, kind: category.kind, size: 32),
              const SizedBox(width: 10),
              Text(
                category.name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  const _DatePicker({
    required this.date,
    required this.onChanged,
    required this.onPick,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final isToday = date == today;
    final isYesterday = date == yesterday;
    final other = !isToday && !isYesterday;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _DateChip(
            label: 'Today',
            selected: isToday,
            onTap: () => onChanged(today),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: _DateChip(
            label: 'Yesterday',
            selected: isYesterday,
            onTap: () => onChanged(yesterday),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: _DateChip(
            label: other ? formatDate(isoDate(date)) : 'Pick date',
            icon: LucideIcons.calendar,
            selected: other,
            onTap: onPick,
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _lime.withValues(alpha: 0.12) : _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? _lime : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: selected ? _lime : _muted),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
