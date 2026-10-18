import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/screens/budgets_section.dart';
import 'package:finance_track/screens/type_page.dart' show categoryNameFor;
import 'package:finance_track/sms/bank_sms.dart';
import 'package:finance_track/sms/sms_inbox.dart';
import 'package:finance_track/widgets/account_chip.dart';
import 'package:finance_track/widgets/bank_logo.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _green = Color(0xFF3DDC84);
const _red = Color(0xFFFF6B6B);

Future<void> reviewBankSms(
  BuildContext context, {
  required Ledger ledger,
  required List<BankSms> messages,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SmsReview(ledger: ledger, messages: messages),
  );
}

Account? accountForSms(BankSms sms, Ledger ledger) {
  final matches = ledger.accounts
      .where((account) => ledger.bankFor(account)?.id == sms.bankId)
      .toList();
  if (matches.isEmpty) return null;
  final digits = sms.accountDigits;
  if (digits != null) {
    for (final account in matches) {
      if (account.name.contains(digits)) return account;
    }
  }
  return matches.first;
}

class SmsReview extends StatefulWidget {
  const SmsReview({super.key, required this.ledger, required this.messages});

  final Ledger ledger;
  final List<BankSms> messages;

  @override
  State<SmsReview> createState() => _SmsReviewState();
}

class _SmsReviewState extends State<SmsReview> {
  final _note = TextEditingController();
  var _index = 0;
  String? _categoryId;
  String? _accountId;
  var _busy = false;
  var _showBody = false;
  var _picked = false;
  var _loan = false;
  String? _loanType;
  String? _firstId;
  final _person = TextEditingController();
  String? _error;

  BankSms get _sms => widget.messages[_index];

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _note.dispose();
    _person.dispose();
    super.dispose();
  }

  List<Category> get _categories => widget.ledger.categories
      .where((category) => category.kind == _sms.kind)
      .toList();

  List<Category> get _ordered {
    final first = _firstId;
    return [
      ..._categories.where((category) => category.id == first),
      ..._categories.where((category) => category.id != first),
    ];
  }

  List<(String, String)> get _loanTypes => _sms.kind == 'income'
      ? const [('borrowed', 'Borrowed from'), ('got_back', 'Paid me back')]
      : const [('lent', 'Lent to'), ('paid_back', 'Paid back')];

  void _prepare() {
    final sms = _sms;
    _note.text = sms.merchant ?? '';
    _picked = false;
    _loan = false;
    _loanType = _loanTypes.first.$1;
    _person.text = sms.merchant ?? '';
    _showBody = false;
    _error = null;
    _accountId =
        accountForSms(sms, widget.ledger)?.id ?? _fallbackAccount()?.id;
    final name = sms.kind == 'income'
        ? (RegExp(
                r'salary|sal\b|payroll',
                caseSensitive: false,
              ).hasMatch(sms.body)
              ? 'Salary'
              : 'Other income')
        : categoryNameFor('${sms.merchant ?? ''} ${sms.body}');
    _categoryId = _categoryNamed(name)?.id;
    _firstId = _categoryId;
    if (sms.kind == 'expense' && name == 'Other' && sms.merchant != null) {
      _askAi(sms);
    }
  }

  Account? _fallbackAccount() {
    final accounts = widget.ledger.accounts;
    for (final account in accounts) {
      if (account.type == 'bank') return account;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  Category? _categoryNamed(String name) {
    for (final category in _categories) {
      if (category.name.toLowerCase() == name.toLowerCase()) return category;
    }
    return null;
  }

  Future<void> _askAi(BankSms sms) async {
    final accountId = _accountId;
    if (accountId == null) return;
    try {
      final drafts = await widget.ledger.api.previewText(
        text: 'paid ${formatRupees(sms.amount)} to ${sms.merchant}',
        accountId: accountId,
        today: isoDate(sms.date),
      );
      if (!mounted || _sms.id != sms.id || _picked || drafts.isEmpty) return;
      final suggested = drafts.first.categoryId;
      if (_categories.any((category) => category.id == suggested)) {
        setState(() => _categoryId = _firstId = suggested);
      }
    } on FinanceException {
      return;
    }
  }

  bool get _maybeDuplicate {
    final day = isoDate(_sms.date);
    return widget.ledger.transactions.any(
      (item) =>
          item.amount == _sms.amount &&
          item.kind == _sms.kind &&
          item.occurredOn == day,
    );
  }

  void _next() {
    if (_index + 1 >= widget.messages.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _prepare();
    });
  }

  Future<void> _saveLoan() async {
    final accountId = _accountId;
    final person = _person.text.trim();
    if (person.isEmpty) {
      setState(() => _error = 'Who was it?');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.ledger.saveDebt(
        person: person,
        type: _loanType ?? _loanTypes.first.$1,
        amount: _sms.amount,
        occurredOn: isoDate(_sms.date),
        accountId: accountId,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      await SmsInbox.markSeen(_sms);
      if (mounted) _next();
    } on FinanceException catch (caught) {
      if (mounted) setState(() => _error = caught.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_loan) return _saveLoan();
    final categoryId = _categoryId;
    final accountId = _accountId;
    if (categoryId == null || accountId == null) {
      setState(
        () =>
            _error = categoryId == null ? 'Pick a category' : 'Pick an account',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.ledger.saveTransaction(
        accountId: accountId,
        categoryId: categoryId,
        amount: _sms.amount,
        kind: _sms.kind,
        occurredOn: isoDate(_sms.date),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      await SmsInbox.markSeen(_sms);
      final category = _categories
          .where((item) => item.id == categoryId)
          .firstOrNull;
      final warnings = _sms.kind == 'expense' && category != null
          ? budgetWarnings(widget.ledger, [category.name])
          : const <String>[];
      if (warnings.isNotEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(warnings.join('\n'))));
      }
      if (mounted) _next();
    } on FinanceException catch (caught) {
      if (mounted) setState(() => _error = caught.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    await SmsInbox.markSeen(_sms);
    if (mounted) _next();
  }

  Future<void> _reportSpam() async {
    final sms = _sms;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Report as spam?'),
        content: Text(
          'Messages from ${senderKey(sms.sender)} will not be asked about again. You can allow them again in Profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report spam', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SmsInbox.reportSpam(sms);
    if (!mounted) return;
    final remaining = widget.messages
        .skip(_index + 1)
        .where((other) => senderKey(other.sender) == senderKey(sms.sender));
    for (final other in remaining) {
      await SmsInbox.markSeen(other);
    }
    if (!mounted) return;
    final rest = widget.messages
        .skip(_index + 1)
        .where((other) => senderKey(other.sender) != senderKey(sms.sender))
        .toList();
    if (rest.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    widget.messages
      ..removeRange(_index + 1, widget.messages.length)
      ..addAll(rest);
    _next();
  }

  Future<void> _chooseAccount() async {
    final picked = await showAccountPicker(
      context,
      accounts: widget.ledger.accounts,
      bankFor: widget.ledger.bankFor,
      currentId: _accountId,
      title: _sms.kind == 'income' ? 'Received in' : 'Paid from',
    );
    if (picked != null && mounted) setState(() => _accountId = picked.id);
  }

  @override
  Widget build(BuildContext context) {
    final sms = _sms;
    final income = sms.kind == 'income';
    final bank = widget.ledger.banks
        .where((item) => item.id == sms.bankId)
        .firstOrNull;
    Account? account;
    for (final item in widget.ledger.accounts) {
      if (item.id == _accountId) account = item;
    }
    final amount = formatRupees(sms.amount);
    final question = income
        ? 'Where did this $amount come from?'
        : 'Where did you spend $amount?';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  LucideIcons.messageSquareText,
                  color: _muted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${sms.app ?? 'Bank SMS'} · ${_index + 1} of ${widget.messages.length}',
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Later', style: TextStyle(color: _muted)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      sms.fromApp
                          ? _AppBadge(name: sms.app!)
                          : BankLogo.round(bank: bank, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${income ? '+' : '-'} $amount',
                              style: TextStyle(
                                color: income ? _green : Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              [
                                sms.app ?? bank?.name ?? senderKey(sms.sender),
                                if (sms.accountDigits != null)
                                  '••${sms.accountDigits}',
                                formatDate(isoDate(sms.date)),
                              ].join(' · '),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _showBody ? 'Hide message' : 'Show message',
                        onPressed: () => setState(() => _showBody = !_showBody),
                        icon: Icon(
                          _showBody
                              ? LucideIcons.chevronUp
                              : LucideIcons.chevronDown,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                  if (_showBody) ...[
                    const SizedBox(height: 12),
                    Text(
                      sms.body,
                      style: const TextStyle(
                        color: Color(0xFFC7C7CC),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_maybeDuplicate)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.copy,
                      color: Color(0xFFF5C451),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You already saved $amount on this day. Skip it if it is the same.',
                        style: const TextStyle(
                          color: Color(0xFFF5C451),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text(
              question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (_loan) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in _loanTypes)
                    _Choice(
                      label: type.$2,
                      icon: CategoryIcon.key(
                        income ? 'borrowed' : 'lent',
                        size: 28,
                      ),
                      selected: type.$1 == _loanType,
                      onTap: () => setState(() => _loanType = type.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _person,
                hint: 'Friend\'s name',
                icon: LucideIcons.userRound,
              ),
            ] else
              _CategoryRows(
                categories: _ordered,
                selectedId: _categoryId,
                onPick: (category) => setState(() {
                  _categoryId = category.id;
                  _picked = true;
                  _error = null;
                }),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _loan = !_loan;
                        _error = null;
                      }),
                icon: Icon(
                  _loan ? LucideIcons.tags : LucideIcons.handCoins,
                  size: 18,
                ),
                label: Text(
                  _loan
                      ? 'Not a loan, pick a category'
                      : income
                      ? 'A friend lent or paid me back'
                      : 'I lent or paid back a friend',
                ),
                style: TextButton.styleFrom(foregroundColor: _lime),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (account != null)
                  Flexible(
                    child: AccountChip(
                      account: account,
                      bank: widget.ledger.bankFor(account),
                      onTap: _busy ? null : _chooseAccount,
                      maxNameWidth: 120,
                      verb: income ? 'Received in' : 'Paid from',
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _chooseAccount,
                    icon: const Icon(LucideIcons.landmark),
                    label: const Text('Pick account'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: income
                    ? 'From whom? e.g. salary'
                    : 'What was it? e.g. lunch',
                hintStyle: const TextStyle(color: Color(0xFF5C5C60)),
                prefixIcon: const Icon(
                  LucideIcons.notebookPen,
                  color: _muted,
                  size: 20,
                ),
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
            const SizedBox(height: 16),
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
                child: Text(
                  _loan
                      ? 'Save to People'
                      : income
                      ? 'Save income'
                      : 'Save spend',
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _busy ? null : _skip,
                    child: const Text(
                      'Not a transaction',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _reportSpam,
                    icon: const Icon(LucideIcons.shieldAlert, size: 18),
                    label: const Text('Report spam'),
                    style: TextButton.styleFrom(foregroundColor: _red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _appColors = <String, int>{
  'GPay': 0xFF1A73E8,
  'PhonePe': 0xFF5F259F,
  'Paytm': 0xFF00BAF2,
  'BHIM': 0xFF00796B,
  'CRED': 0xFF1C1C1E,
};

class _AppBadge extends StatelessWidget {
  const _AppBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(_appColors[name] ?? 0xFF3A3A3C),
      ),
      child: FittedBox(
        child: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget icon;
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
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            color: selected ? _lime.withValues(alpha: 0.12) : _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? _lime : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
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

class _CategoryRows extends StatelessWidget {
  const _CategoryRows({
    required this.categories,
    required this.selectedId,
    required this.onPick,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<Category> onPick;

  @override
  Widget build(BuildContext context) {
    Widget chip(Category category) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _Choice(
        label: category.name,
        icon: CategoryIcon(name: category.name, kind: category.kind, size: 28),
        selected: category.id == selectedId,
        onTap: () => onPick(category),
      ),
    );
    final top = [for (var i = 0; i < categories.length; i += 2) categories[i]];
    final bottom = [
      for (var i = 1; i < categories.length; i += 2) categories[i],
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [for (final category in top) chip(category)]),
          const SizedBox(height: 8),
          Row(children: [for (final category in bottom) chip(category)]),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
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
