import 'dart:typed_data';

import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/bank_logo.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);

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
  required Future<Bank> Function({
    required String name,
    required List<int> logo,
    required String logoType,
    required List<int> mark,
    required String markType,
  })
  onCreateBrand,
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
    builder: (context) => _CardEditor(
      banks: banks,
      kind: existing?.cardKind ?? kind,
      existing: existing,
      onCreateBrand: onCreateBrand,
    ),
  );
}

class CreditCardScreen extends StatelessWidget {
  const CreditCardScreen({
    super.key,
    required this.ledger,
    required this.accountId,
  });

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
          return const Scaffold(
            body: Center(child: Text('This card was removed')),
          );
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
                  _Figure(
                    label: 'Free',
                    amount: card.available ?? card.balance,
                  ),
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
                  onPressed: (card.used ?? 0) > 0
                      ? () => _pay(context, card)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: _card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Pay bill'),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Recent spends',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (spends.isEmpty)
                const Text(
                  'No spends on this card yet.',
                  style: TextStyle(color: _muted),
                )
              else
                for (final item in spends.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.categoryName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      item.occurredOn,
                      style: const TextStyle(color: _muted),
                    ),
                    trailing: Text(
                      formatRupees(item.amount),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, Account card) async {
    final banks = await ledger.loadBanks(refresh: true);
    if (!context.mounted) return;
    final result = await showCardEditor(
      context,
      banks: banks,
      kind: card.cardKind ?? 'bank',
      existing: card,
      onCreateBrand: ledger.createCardBrand,
    );
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
    final sources = [
      for (final account in ledger.accounts)
        if (!account.isCard) account,
    ];
    if (sources.isEmpty) {
      _message(context, 'Add a bank or cash account to pay this card');
      return;
    }
    Category? category;
    for (final item in ledger.categories) {
      if (item.kind == 'expense' && item.name == 'Other') category = item;
    }
    category ??= ledger.categories
        .where((item) => item.kind == 'expense')
        .firstOrNull;
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
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
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
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  formatRupees(amount),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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
      setState(
        () => _error =
            'That is more than the ${formatRupees(used)} currently used',
      );
      return;
    }
    Navigator.pop(context, _Payment(accountId: _accountId, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pay bill',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
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
  const _CardEditor({
    required this.banks,
    required this.kind,
    required this.onCreateBrand,
    this.existing,
  });

  final List<Bank> banks;
  final String kind;
  final Account? existing;
  final Future<Bank> Function({
    required String name,
    required List<int> logo,
    required String logoType,
    required List<int> mark,
    required String markType,
  })
  onCreateBrand;

  @override
  State<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<_CardEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _limit = TextEditingController(
    text: widget.existing?.limitAmount == null
        ? ''
        : _rupees(widget.existing!.limitAmount!),
  );
  late List<Bank> _banks = [...widget.banks];
  late Bank? _bank = _selected(widget.banks, widget.existing?.bankId);
  final _bankSearch = TextEditingController();
  final _brandName = TextEditingController();
  late int? _billDay =
      widget.existing?.billDay ?? (widget.kind == 'bank' ? 1 : null);
  late int? _dueDay =
      widget.existing?.dueDay ?? (widget.kind == 'bank' ? 15 : null);
  Uint8List? _logo;
  Uint8List? _mark;
  String? _logoType;
  String? _markType;
  var _adding = false;
  var _savingBrand = false;
  String? _error;

  bool get _bankCard => widget.kind == 'bank';

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _bankSearch.dispose();
    _brandName.dispose();
    super.dispose();
  }

  Bank? _selected(List<Bank> banks, String? id) {
    for (final bank in banks) {
      if (bank.id == id) return bank;
    }
    return null;
  }

  void _save() {
    final name = _name.text.trim();
    final limit = parseMoney(_limit.text.replaceAll(',', ''));
    if (name.isEmpty) {
      setState(() => _error = 'Enter a card name');
      return;
    }
    if (_bank == null) {
      setState(() => _error = 'Pick the bank');
      return;
    }
    if (limit == null || limit < 1) {
      setState(
        () => _error = _bankCard
            ? 'Enter the sanctioned limit'
            : 'Enter the FD amount',
      );
      return;
    }
    Navigator.pop(
      context,
      CardDraft(
        name: name,
        kind: widget.kind,
        bankId: _bank?.id,
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
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
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
            TextField(
              controller: _bankSearch,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('Search a card or bank'),
            ),
            const SizedBox(height: 8),
            _BankList(
              banks: _shownBanks(),
              selectedId: _bank?.id,
              onTap: (bank) => setState(() {
                _bank = bank;
                _error = null;
              }),
            ),
            if (_bank != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  BankLogo(bank: _bank, width: 84, height: 44),
                  const SizedBox(width: 12),
                  BankLogo.round(bank: _bank, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _bank!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _savingBrand
                    ? null
                    : () => setState(() => _adding = !_adding),
                icon: Icon(
                  _adding ? LucideIcons.x : LucideIcons.plus,
                  size: 18,
                ),
                label: Text(_adding ? 'Hide new logo' : 'Add a card logo'),
                style: TextButton.styleFrom(foregroundColor: _lime),
              ),
            ),
            if (_adding) ...[
              TextField(
                controller: _brandName,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Name others will search'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _UploadTile(
                    label: 'Logo only',
                    bytes: _mark,
                    round: true,
                    onTap: _savingBrand ? null : () => _pickImage(mark: true),
                  ),
                  const SizedBox(width: 12),
                  _UploadTile(
                    label: 'Logo with name',
                    bytes: _logo,
                    onTap: _savingBrand ? null : () => _pickImage(mark: false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _savingBrand ? null : _saveBrand,
                style: FilledButton.styleFrom(
                  backgroundColor: _lime,
                  foregroundColor: const Color(0xFF17310C),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_savingBrand ? 'Saving' : 'Save logo'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _limit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration(
                _bankCard ? 'Sanctioned limit' : 'FD amount',
              ),
            ),
            if (_bankCard) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dayField(
                      'Bill day',
                      _billDay,
                      (day) => setState(() => _billDay = day),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dayField(
                      'Due day',
                      _dueDay,
                      (day) => setState(() => _dueDay = day),
                    ),
                  ),
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
                  CardDraft(
                    name: widget.existing!.name,
                    kind: widget.kind,
                    limitAmount: widget.existing!.limitAmount ?? 1,
                    delete: true,
                  ),
                ),
                child: const Text(
                  'Delete card',
                  style: TextStyle(color: Color(0xFFFF6B6B)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Bank> _shownBanks() {
    final query = _bankSearch.text.trim().toLowerCase();
    return [
      for (final bank in _banks)
        if (query.isEmpty ||
            bank.name.toLowerCase().contains(query) ||
            bank.short.toLowerCase().contains(query))
          bank,
    ];
  }

  Future<void> _pickImage({required bool mark}) async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    final type = _imageType(shot);
    if (!mounted) return;
    setState(() {
      if (mark) {
        _mark = bytes;
        _markType = type;
      } else {
        _logo = bytes;
        _logoType = type;
      }
      _error = null;
    });
  }

  String _imageType(XFile file) {
    final mime = file.mimeType;
    if (mime == 'image/png' || mime == 'image/webp' || mime == 'image/jpeg') {
      return mime!;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _saveBrand() async {
    final name = _brandName.text.trim();
    final logo = _logo;
    final mark = _mark;
    if (name.length < 2) {
      setState(() => _error = 'Enter the name others will search');
      return;
    }
    if (logo == null || mark == null) {
      setState(() => _error = 'Add the logo only and the logo with name');
      return;
    }
    setState(() {
      _savingBrand = true;
      _error = null;
    });
    try {
      final bank = await widget.onCreateBrand(
        name: name,
        logo: logo,
        logoType: _logoType ?? 'image/jpeg',
        mark: mark,
        markType: _markType ?? 'image/jpeg',
      );
      if (!mounted) return;
      setState(() {
        _banks = [
          for (final item in _banks)
            if (item.id != bank.id) item,
          bank,
        ];
        _bank = bank;
        _adding = false;
        _savingBrand = false;
        if (_name.text.trim().isEmpty) _name.text = bank.name;
      });
    } on FinanceException catch (error) {
      if (!mounted) return;
      setState(() {
        _savingBrand = false;
        _error = error.message;
      });
    }
  }

  Widget _dayField(String label, int? value, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      dropdownColor: _card,
      style: const TextStyle(color: Colors.white),
      decoration: _fieldDecoration(label),
      items: [
        for (var day = 1; day <= 28; day++)
          DropdownMenuItem(value: day, child: Text('$day')),
      ],
      onChanged: onChanged,
    );
  }
}

class _BankList extends StatelessWidget {
  const _BankList({
    required this.banks,
    required this.selectedId,
    required this.onTap,
  });

  final List<Bank> banks;
  final String? selectedId;
  final ValueChanged<Bank> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        height: 220,
        child: banks.isEmpty
            ? const Center(
                child: Text('No card found', style: TextStyle(color: _muted)),
              )
            : ListView.separated(
                itemCount: banks.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: _line),
                itemBuilder: (context, index) {
                  final bank = banks[index];
                  final selected = bank.id == selectedId;
                  return ListTile(
                    onTap: () => onTap(bank),
                    leading: BankLogo(bank: bank, width: 56, height: 32),
                    title: Text(
                      bank.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(LucideIcons.check, color: _lime, size: 18)
                        : null,
                  );
                },
              ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.label,
    required this.bytes,
    required this.onTap,
    this.round = false,
  });

  final String label;
  final Uint8List? bytes;
  final VoidCallback? onTap;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 72,
              width: double.infinity,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(round ? 36 : 16),
              ),
              child: bytes == null
                  ? const Icon(LucideIcons.imagePlus, color: _muted)
                  : Image.memory(bytes!, fit: BoxFit.contain),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

String _rupees(int paise) {
  final rupees = paise / 100;
  return paise % 100 == 0
      ? rupees.toStringAsFixed(0)
      : rupees.toStringAsFixed(2);
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _muted),
    filled: true,
    fillColor: _field,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white),
    ),
  );
}
