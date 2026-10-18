import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/screens/people_section.dart';
import 'package:finance_track/widgets/bank_logo.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key, required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (ledger.accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Add your bank accounts and cash to start tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
              )
            else
              Material(
                color: _card,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (index, account) in ledger.accounts.indexed) ...[
                      if (index > 0) const Divider(height: 1, color: _line),
                      _AccountRow(
                        account: account,
                        bank: ledger.bankFor(account),
                        onTap: () => _editAccount(context, account),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _addAccount(context),
                icon: const Icon(LucideIcons.plus),
                label: const Text('Add account'),
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
            const SizedBox(height: 32),
            PeopleSection(ledger: ledger),
          ],
        );
      },
    );
  }

  Future<_NewAccount?> _openSheet(
    BuildContext context, {
    Account? existing,
  }) async {
    final banks = await ledger.loadBanks();
    if (!context.mounted) return null;
    return showModalBottomSheet<_NewAccount>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _AddAccountSheet(
        banks: banks,
        existing: existing,
        existingBank: existing == null ? null : ledger.bankFor(existing),
      ),
    );
  }

  Future<void> _addAccount(BuildContext context) async {
    final result = await _openSheet(context);
    if (result == null || !context.mounted) return;
    try {
      await ledger.createAccount(
        name: result.name,
        type: result.type,
        openingBalance: result.openingBalance,
        bankId: result.bankId,
      );
    } on FinanceException catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _editAccount(BuildContext context, Account account) async {
    final result = await _openSheet(context, existing: account);
    if (result == null || !context.mounted) return;
    try {
      if (result.delete) {
        if (!await _confirmDelete(context, account)) return;
        await ledger.deleteAccount(account.id);
        if (context.mounted) _showError(context, '${account.name} deleted');
        return;
      }
      await ledger.updateAccount(
        id: account.id,
        name: result.name,
        type: result.type,
        openingBalance: result.openingBalance,
        bankId: result.bankId,
      );
    } on FinanceException catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<bool> _confirmDelete(BuildContext context, Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text('Delete ${account.name}?'),
        content: const Text(
          'This also deletes every transaction and scheduled entry saved in this account. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.bank,
    required this.onTap,
  });

  final Account account;
  final Bank? bank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cash = account.type == 'cash';
    final subtitle = cash
        ? 'Cash'
        : bank != null && bank!.name != account.name
        ? bank!.name
        : 'Bank account';
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: BankLogo(bank: bank, cash: cash, width: 68, height: 42),
      title: Text(
        account.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: _muted)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            account.balance < 0
                ? '- ${formatRupees(-account.balance)}'
                : formatRupees(account.balance),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text('balance', style: TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _NewAccount {
  const _NewAccount({
    required this.name,
    required this.type,
    required this.openingBalance,
    this.bankId,
  }) : delete = false;

  const _NewAccount.delete()
    : name = '',
      type = '',
      openingBalance = 0,
      bankId = null,
      delete = true;

  final String name;
  final String type;
  final int openingBalance;
  final String? bankId;
  final bool delete;
}

String _balanceText(int paise) {
  final rupees = paise / 100;
  return paise % 100 == 0
      ? rupees.toStringAsFixed(0)
      : rupees.toStringAsFixed(2);
}

class _AddAccountSheet extends StatefulWidget {
  const _AddAccountSheet({
    required this.banks,
    this.existing,
    this.existingBank,
  });

  final List<Bank> banks;
  final Account? existing;
  final Bank? existingBank;

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _balance = TextEditingController(
    text: _balanceText(widget.existing?.openingBalance ?? 0),
  );
  final _search = TextEditingController();
  late var _type = widget.existing?.type ?? 'bank';
  late Bank? _bank = widget.existingBank;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _search.dispose();
    super.dispose();
  }

  void _pick(Bank bank) {
    setState(() {
      final previous = _bank;
      final nameWasBank =
          _name.text.trim().isEmpty || _name.text.trim() == previous?.name;
      _bank = bank;
      _error = null;
      if (bank.id != 'other' && nameWasBank) _name.text = bank.name;
    });
  }

  void _save() {
    final name = _name.text.trim().isEmpty && _type == 'cash'
        ? 'Cash'
        : _name.text.trim();
    if (_type == 'bank' && _bank == null) {
      setState(() => _error = 'Pick your bank');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Enter an account name');
      return;
    }
    final openingBalance = parseOpeningBalance(_balance.text);
    if (openingBalance == null) {
      setState(() => _error = 'Enter a valid opening balance');
      return;
    }
    Navigator.pop(
      context,
      _NewAccount(
        name: name,
        type: _type,
        openingBalance: openingBalance,
        bankId: _type == 'bank' ? _bank?.id : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final banks = widget.banks
        .where(
          (bank) =>
              query.isEmpty ||
              bank.name.toLowerCase().contains(query) ||
              bank.short.toLowerCase().contains(query),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? 'Edit account' : 'Add account',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _TypeSwitch(
                    type: _type,
                    onChanged: (type) => setState(() {
                      _type = type;
                      _error = null;
                      if (type == 'cash' && _bank != null) _name.clear();
                    }),
                  ),
                ],
              ),
            ),
            if (_type == 'bank') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration(
                    'Search your bank',
                    const Icon(LucideIcons.search, color: _muted, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: banks.isEmpty
                    ? const Center(
                        child: Text(
                          'No bank found. Pick "Other bank".',
                          style: TextStyle(color: _muted),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              mainAxisExtent: 98,
                            ),
                        itemCount: banks.length,
                        itemBuilder: (context, index) {
                          final bank = banks[index];
                          return _BankTile(
                            bank: bank,
                            selected: _bank?.id == bank.id,
                            onTap: () => _pick(bank),
                          );
                        },
                      ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: BankLogo(cash: true, width: 120, height: 88),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration(
                            _type == 'cash' ? 'Cash' : 'Account name',
                            null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _balance,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration(
                            'Balance',
                            null,
                            prefix: '₹ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFF6B6B)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _save,
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
                      child: Text(_editing ? 'Save changes' : 'Save account'),
                    ),
                  ),
                  if (_editing)
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, const _NewAccount.delete()),
                      icon: const Icon(LucideIcons.trash2, size: 18),
                      label: const Text('Delete account'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF6B6B),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _decoration(String hint, Widget? icon, {String? prefix}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF5C5C60)),
    prefixIcon: icon,
    prefixText: prefix,
    prefixStyle: const TextStyle(color: _muted),
    filled: true,
    fillColor: _field,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    enabledBorder: border(_line),
    focusedBorder: border(Colors.white),
  );
}

class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.type, required this.onChanged});

  final String type;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String value, String label) {
      final selected = type == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _line : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('bank', 'Bank'), option('cash', 'Cash')],
      ),
    );
  }
}

class _BankTile extends StatelessWidget {
  const _BankTile({
    required this.bank,
    required this.selected,
    required this.onTap,
  });

  final Bank bank;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: bank.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
          decoration: BoxDecoration(
            color: selected
                ? _lime.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _lime : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) => BankLogo(
                  bank: bank,
                  width: constraints.maxWidth,
                  height: 50,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    bank.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFC7C7CC),
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
