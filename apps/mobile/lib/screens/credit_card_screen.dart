import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/bank_logo.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);

class CardDraft {
  const CardDraft({
    required this.name,
    required this.kind,
    required this.limitAmount,
    this.bankId,
    this.billDay,
    this.dueDay,
    this.delete = false,
  });

  final String name;
  final String kind;
  final int limitAmount;
  final String? bankId;
  final int? billDay;
  final int? dueDay;
  final bool delete;
}

Future<CardDraft?> showCardEditor(
  BuildContext context, {
  required List<Bank> banks,
  required String kind,
  Account? existing,
}) {
  return showModalBottomSheet<CardDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _CardEditor(banks: banks, kind: existing?.cardKind ?? kind, existing: existing),
  );
}

class CreditCardScreen extends StatelessWidget {
  const CreditCardScreen({super.key, required this.ledger, required this.accountId});

  final Ledger ledger;
  final String accountId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) {
        Account? account;
        for (final item in ledger.accounts) {
          if (item.id == accountId) account = item;
        }
        if (account == null) {
          return const Scaffold(body: Center(child: Text('This card was removed')));
        }
        final card = account;
        final spends = [
          for (final item in ledger.transactions)
            if (item.accountId == card.id && item.cardEffect != 'payment') item,
        ];
        return Scaffold(
          appBar: AppBar(
            title: Text(card.name),
            actions: [
              IconButton(
                tooltip: 'Edit card',
                onPressed: () => _edit(context, card),
                icon: const Icon(LucideIcons.pencil),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  _Figure(label: 'Limit', amount: card.limitAmount ?? 0),
                  _Figure(label: 'Used', amount: card.used ?? 0),
                  _Figure(label: 'Free', amount: card.available ?? card.balance),
                ],
              ),
              if (card.dueDay != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Next due ${_dueLabel(card.dueDay!)}',
                  style: const TextStyle(color: _muted, fontSize: 15),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: (card.used ?? 0) > 0 ? () => _pay(context, card) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: _card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Pay bill'),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Recent spends',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (spends.isEmpty)
                const Text('No spends on this card yet.', style: TextStyle(color: _muted))
              else
                for (final item in spends.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.categoryName, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(item.occurredOn, style: const TextStyle(color: _muted)),
                    trailing: Text(formatRupees(item.amount), style: const TextStyle(color: Colors.white)),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, Account card) async {
    final banks = await ledger.loadBanks();
    if (!context.mounted) return;
    final result = await showCardEditor(context, banks: banks, kind: card.cardKind ?? 'bank', existing: card);
    if (result == null || !context.mounted) return;
    try {
      if (result.delete) {
        await ledger.deleteAccount(card.id);
        if (context.mounted) Navigator.of(context).pop();
        return;
      }
      await ledger.updateAccount(
        id: card.id,
        name: result.name,
        type: 'credit',
        openingBalance: 0,
        bankId: result.bankId,
        cardKind: result.kind,
        limitAmount: result.limitAmount,
        billDay: result.billDay,
        dueDay: result.dueDay,
      );
    } on FinanceException catch (error) {
      if (context.mounted) _message(context, error.message);
    }
  }

  Future<void> _pay(BuildContext context, Account card) async {
    final sources = [for (final account in ledger.accounts) if (!account.isCard) account];
    if (sources.isEmpty) {
      _message(context, 'Add a bank or cash account to pay this card');
      return;
    }
    Category? category;
    for (final item in ledger.categories) {
      if (item.kind == 'expense' && item.name == 'Other') category = item;
    }
    category ??= ledger.categories.where((item) => item.kind == 'expense').firstOrNull;
    if (category == null) {
      _message(context, 'Add an expense category first');
      return;
    }
    final paid = await showModalBottomSheet<_Payment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _PaySheet(card: card, sources: sources),
    );
    if (paid == null || !context.mounted) return;
    try {
      await ledger.saveTransaction(
        accountId: paid.accountId,
        categoryId: category.id,
        amount: paid.amount,
        kind: 'expense',
        occurredOn: isoDate(DateTime.now()),
        note: 'Card payment ${card.name}',
        cardEffect: 'payment',
        cardId: card.id,
      );
    } on FinanceException catch (error) {
      if (context.mounted) _message(context, error.message);
    }
  }
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

String _dueLabel(int dueDay) {
  final today = DateTime.now();
  var year = today.year;
  var month = today.month;
  if (today.day > dueDay) {
    month += 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
  }
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '$dueDay ${months[month - 1]} $year';
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  formatRupees(amount),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Payment {
  const _Payment({required this.accountId, required this.amount});

  final String accountId;
  final int amount;
}

class _PaySheet extends StatefulWidget {
  const _PaySheet({required this.card, required this.sources});

  final Account card;
  final List<Account> sources;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late String _accountId = widget.sources.first.id;
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final amount = parseMoney(_amount.text.replaceAll(',', ''));
    final used = widget.card.used ?? 0;
    if (amount == null) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (amount > used) {
      setState(() => _error = 'That is more than the ${formatRupees(used)} currently used');
      return;
    }
    Navigator.pop(context, _Payment(accountId: _accountId, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pay bill',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Up to ${formatRupees(widget.card.used ?? 0)} frees that much of the limit.',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _accountId,
            dropdownColor: _card,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Pay from'),
            items: [
              for (final account in widget.sources)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _accountId = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Amount'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B))),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Pay'),
          ),
        ],
      ),
    );
  }
}

class _CardEditor extends StatefulWidget {
  const _CardEditor({required this.banks, required this.kind, this.existing});

  final List<Bank> banks;
  final String kind;
  final Account? existing;

  @override
  State<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<_CardEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _limit = TextEditingController(
    text: widget.existing?.limitAmount == null ? '' : _rupees(widget.existing!.limitAmount!),
  );
  late String? _bankId = widget.existing?.bankId;
  late int? _billDay = widget.existing?.billDay ?? (widget.kind == 'bank' ? 1 : null);
  late int? _dueDay = widget.existing?.dueDay ?? (widget.kind == 'bank' ? 15 : null);
  String? _error;

  bool get _bankCard => widget.kind == 'bank';

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final limit = parseMoney(_limit.text.replaceAll(',', ''));
    if (name.isEmpty) {
      setState(() => _error = 'Enter a card name');
      return;
    }
    if (_bankId == null) {
      setState(() => _error = 'Pick the bank');
      return;
    }
    if (limit == null || limit < 1) {
      setState(() => _error = _bankCard ? 'Enter the sanctioned limit' : 'Enter the FD amount');
      return;
    }
    Navigator.pop(
      context,
      CardDraft(
        name: name,
        kind: widget.kind,
        bankId: _bankId,
        limitAmount: limit,
        billDay: _bankCard ? _billDay : null,
        dueDay: _bankCard ? _dueDay : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing != null
        ? 'Edit card'
        : _bankCard
        ? 'Bank card'
        : 'FD-backed card';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              _bankCard
                  ? 'The limit is the amount the bank sanctioned. Paying the bill frees that much again.'
                  : 'The limit is the FD amount. Paying the bill frees that much for the next purchase.',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('Card name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _bankId,
              dropdownColor: _card,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('Bank'),
              items: [
                for (final bank in widget.banks)
                  DropdownMenuItem(
                    value: bank.id,
                    child: Row(
                      children: [
                        BankLogo(bank: bank, width: 36, height: 22),
                        const SizedBox(width: 8),
                        Flexible(child: Text(bank.name, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _bankId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration(_bankCard ? 'Sanctioned limit' : 'FD amount'),
            ),
            if (_bankCard) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _dayField('Bill day', _billDay, (day) => setState(() => _billDay = day))),
                  const SizedBox(width: 12),
                  Expanded(child: _dayField('Due day', _dueDay, (day) => setState(() => _dueDay = day))),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B))),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(widget.existing == null ? 'Add card' : 'Save'),
            ),
            if (widget.existing != null)
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  CardDraft(name: widget.existing!.name, kind: widget.kind, limitAmount: widget.existing!.limitAmount ?? 1, delete: true),
                ),
                child: const Text('Delete card', style: TextStyle(color: Color(0xFFFF6B6B))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dayField(String label, int? value, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      dropdownColor: _card,
      style: const TextStyle(color: Colors.white),
      decoration: _fieldDecoration(label),
      items: [
        for (var day = 1; day <= 28; day++) DropdownMenuItem(value: day, child: Text('$day')),
      ],
      onChanged: onChanged,
    );
  }
}

String _rupees(int paise) {
  final rupees = paise / 100;
  return paise % 100 == 0 ? rupees.toStringAsFixed(0) : rupees.toStringAsFixed(2);
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _muted),
    filled: true,
    fillColor: _field,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white)),
  );
}
