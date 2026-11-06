import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _lime = Color(0xFFC8F57A);
const _ink = Color(0xFF17310C);
const _field = Color(0xFF2C2C2E);
const _muted = Color(0xFF8E8E93);

class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({super.key, required this.ledger, this.existing});

  final Ledger ledger;
  final Schedule? existing;

  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _kind;
  late String _repeat;
  late String? _accountId;
  late String? _categoryId;
  late int _day;
  late DateTime _date;
  TimeOfDay? _time;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final today = DateTime.now();
    _kind = existing?.kind ?? 'expense';
    _repeat = existing?.monthly == true ? 'monthly' : 'once';
    _amount = TextEditingController(text: existing == null ? '' : _rupees(existing.amount));
    _note = TextEditingController(text: existing?.note ?? '');
    _accountId = _known(widget.ledger.accounts.map((item) => item.id), existing?.accountId) ??
        widget.ledger.accounts.firstOrNull?.id;
    _categoryId = _categoryFor(existing);
    _day = existing?.dayOfMonth ?? today.day;
    _date = _dateOf(existing?.nextOn) ?? today;
    _time = _clock(existing?.atTime);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _known(Iterable<String> ids, String? id) {
    if (id == null) return null;
    return ids.contains(id) ? id : null;
  }

  String? _categoryFor(Schedule? existing) {
    final matches = _categories();
    final saved = existing?.categoryId;
    if (saved != null && matches.any((item) => item.id == saved)) return saved;
    final name = existing?.categoryName.toLowerCase();
    return matches
            .where((item) => item.name.toLowerCase() == name)
            .firstOrNull
            ?.id ??
        matches.firstOrNull?.id;
  }

  List<Category> _categories() {
    return widget.ledger.categories.where((item) => item.kind == _kind).toList();
  }

  DateTime? _dateOf(String? iso) {
    if (iso == null) return null;
    final parts = iso.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  TimeOfDay? _clock(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _rupees(int paise) {
    if (paise % 100 == 0) return (paise ~/ 100).toString();
    return formatMoney(paise);
  }

  DateTime _nextMonthly(int day) {
    final today = DateTime.now();
    final thisMonth = DateTime(today.year, today.month, _safeDay(today.year, today.month, day));
    final start = DateTime(today.year, today.month, today.day);
    if (!thisMonth.isBefore(start)) return thisMonth;
    return DateTime(today.year, today.month + 1, _safeDay(today.year, today.month + 1, day));
  }

  int _safeDay(int year, int month, int day) {
    final last = DateTime(year, month + 1, 0).day;
    return day.clamp(1, last);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _day = picked.day;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    setState(() => _time = picked);
  }

  Future<void> _save() async {
    final accountId = _accountId;
    final categories = _categories();
    final categoryId = categories.any((item) => item.id == _categoryId) ? _categoryId : categories.firstOrNull?.id;
    final amount = parseMoney(_amount.text.trim());
    if (accountId == null) {
      setState(() => _error = 'Add an account first');
      return;
    }
    if (categoryId == null) {
      setState(() => _error = 'Add a ${_kind == 'income' ? 'income' : 'expense'} category first');
      return;
    }
    if (amount == null) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    final monthly = _repeat == 'monthly';
    final date = monthly ? _nextMonthly(_day) : _date;
    final note = _note.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.ledger.saveSchedule(
        id: widget.existing?.id,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        kind: _kind,
        note: note.isEmpty ? null : note,
        repeat: monthly ? 'monthly' : 'once',
        dayOfMonth: monthly ? _day : date.day,
        nextOn: isoDate(date),
        atTime: _time == null ? null : clockTime(DateTime(2026, 1, 1, _time!.hour, _time!.minute)),
      );
      if (mounted) Navigator.pop(context, true);
    } on FinanceException catch (caught) {
      if (mounted) setState(() => _error = caught.message);
    } catch (caught) {
      if (mounted) setState(() => _error = '$caught');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.ledger.accounts;
    final categories = _categories();
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFF3A3A3C), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              editing ? 'Edit plan' : 'New plan',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_kind},
              onSelectionChanged: (value) {
                setState(() {
                  _kind = value.first;
                  _categoryId = _categories().firstOrNull?.id;
                });
              },
            ),
            const SizedBox(height: 14),
            _box(label: 'Amount', child: _input(_amount, 'Rupees', digits: true)),
            const SizedBox(height: 14),
            _box(label: 'Note', child: _input(_note, 'Rent, salary, SIP')),
            const SizedBox(height: 14),
            _box(
              label: 'Account',
              child: _menu<String>(
                value: accounts.any((item) => item.id == _accountId) ? _accountId : null,
                hint: 'Choose an account',
                items: [
                  for (final account in accounts) DropdownMenuItem(value: account.id, child: Text(account.name)),
                ],
                onChanged: (value) => setState(() => _accountId = value),
              ),
            ),
            const SizedBox(height: 14),
            _box(
              label: 'Category',
              child: _menu<String>(
                value: categories.any((item) => item.id == _categoryId) ? _categoryId : null,
                hint: categories.isEmpty ? 'No categories yet' : 'Choose a category',
                items: [
                  for (final category in categories)
                    DropdownMenuItem(value: category.id, child: Text(category.name)),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'once', label: Text('Once')),
                ButtonSegment(value: 'monthly', label: Text('Every month')),
              ],
              selected: {_repeat},
              onSelectionChanged: (value) => setState(() => _repeat = value.first),
            ),
            const SizedBox(height: 14),
            if (_repeat == 'monthly')
              _box(
                label: 'Day of the month',
                child: _menu<int>(
                  value: _day,
                  hint: 'Day',
                  items: [
                    for (var day = 1; day <= 31; day++) DropdownMenuItem(value: day, child: Text('Day $day')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _day = value);
                  },
                ),
              )
            else
              _box(
                label: 'Date',
                child: _choice(formatDate(isoDate(_date)), _pickDate),
              ),
            const SizedBox(height: 14),
            _box(
              label: 'Time',
              child: Row(
                children: [
                  Expanded(child: _choice(_time == null ? 'No set time' : _time!.format(context), _pickTime)),
                  if (_time != null)
                    IconButton(
                      tooltip: 'Clear time',
                      onPressed: () => setState(() => _time = null),
                      icon: const Icon(Icons.close, color: _muted),
                    ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B))),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _lime,
                  foregroundColor: _ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(_saving ? 'Saving' : 'Save plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _input(TextEditingController controller, String hint, {bool digits = false}) {
    return TextField(
      controller: controller,
      keyboardType: digits ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: digits ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(hint),
    );
  }

  Widget _menu<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      dropdownColor: _field,
      decoration: _decoration(hint),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _choice(String label, VoidCallback onTap) {
    return Material(
      color: _field,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted),
      filled: true,
      fillColor: _field,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }
}
