import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/account_chip.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _green = Color(0xFF3DDC84);
const _orange = Color(0xFFFFB35C);
const _red = Color(0xFFFF6B6B);

const debtTypeLabels = {
  'lent': 'I lent',
  'borrowed': 'I borrowed',
  'got_back': 'They paid me back',
  'paid_back': 'I paid them back',
};

String personStatus(Person person) {
  if (person.balance > 0) return 'owes you ${formatRupees(person.balance)}';
  if (person.balance < 0) return 'you owe ${formatRupees(-person.balance)}';
  return 'all settled';
}

class PeopleSection extends StatelessWidget {
  const PeopleSection({super.key, required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final debts = ledger.debts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'People',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => showDebtSheet(context, ledger: ledger),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Lend or borrow'),
              style: TextButton.styleFrom(foregroundColor: _lime),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Total(
                label: 'You will get',
                amount: debts.owedToYou,
                color: _green,
                iconKey: 'lent',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Total(
                label: 'You owe',
                amount: debts.youOwe,
                color: _orange,
                iconKey: 'borrowed',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (debts.people.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Lent money to a friend or borrowed some? Add it here, or just type "lent 500 to Ravi".',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.4),
            ),
          )
        else
          Material(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, person) in debts.people.indexed) ...[
                  if (index > 0) const Divider(height: 1, color: _line),
                  _PersonRow(
                    person: person,
                    onTap: () => showPersonSheet(
                      context,
                      ledger: ledger,
                      person: person.name,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.amount,
    required this.color,
    required this.iconKey,
  });

  final String label;
  final int amount;
  final Color color;
  final String iconKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CategoryIcon.key(iconKey, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupees(amount),
                    style: TextStyle(
                      color: amount == 0 ? Colors.white : color,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onTap});

  final Person person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = person.balance > 0
        ? _green
        : person.balance < 0
        ? _orange
        : _muted;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(name: person.name),
      title: Text(
        person.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Last on ${formatDate(person.lastOn)}',
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      trailing: Text(
        personStatus(person),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.size = 42});

  final String name;
  final double size;

  static const _colors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF6C00),
    Color(0xFFAB47BC),
    Color(0xFF42A5F5),
    Color(0xFFEC407A),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final color =
        _colors[trimmed.toLowerCase().hashCode.abs() % _colors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Future<void> showPersonSheet(
  BuildContext context, {
  required Ledger ledger,
  required String person,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _PersonSheet(ledger: ledger, person: person),
  );
}

class _PersonSheet extends StatelessWidget {
  const _PersonSheet({required this.ledger, required this.person});

  final Ledger ledger;
  final String person;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) {
        final key = person.trim().toLowerCase();
        final match = ledger.debts.people
            .where((item) => item.name.trim().toLowerCase() == key)
            .firstOrNull;
        final entries = ledger.debts.entriesFor(person);
        final balance = match?.balance ?? 0;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              const _Handle(),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Avatar(name: match?.name ?? person, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match?.name ?? person,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          match == null ? 'No entries' : personStatus(match),
                          style: TextStyle(
                            color: balance > 0
                                ? _green
                                : balance < 0
                                ? _orange
                                : _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (balance != 0) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => showDebtSheet(
                          context,
                          ledger: ledger,
                          person: match?.name ?? person,
                          type: balance > 0 ? 'got_back' : 'paid_back',
                          amount: balance.abs(),
                        ),
                        icon: const Icon(LucideIcons.circleCheck, size: 18),
                        label: const Text('Settle up'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showDebtSheet(
                        context,
                        ledger: ledger,
                        person: match?.name ?? person,
                      ),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('Add entry'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _line),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
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
              const SizedBox(height: 8),
              for (final entry in entries)
                _EntryRow(
                  entry: entry,
                  onDelete: () => _delete(context, entry),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, DebtEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete this entry?'),
        content: Text(
          '${debtTypeLabels[entry.type]} ${formatRupees(entry.amount)} on ${formatDate(entry.occurredOn)}. The account balance changes back.',
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
    if (confirmed != true) return;
    try {
      await ledger.deleteDebt(entry.id);
    } on FinanceException catch (caught) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(caught.message)));
      }
    }
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onDelete});

  final DebtEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      formatDate(entry.occurredOn),
      if (entry.accountName != null) entry.accountName!,
      if (entry.note != null && entry.note!.isNotEmpty) entry.note!,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onLongPress: onDelete,
      leading: CategoryIcon.key(entry.moneyIn ? 'borrowed' : 'lent', size: 40),
      title: Text(
        debtTypeLabels[entry.type] ?? entry.type,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        details,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${entry.moneyIn ? '+' : '-'}${formatRupees(entry.amount)}',
            style: TextStyle(
              color: entry.moneyIn ? _green : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(LucideIcons.trash2, color: _muted, size: 18),
          ),
        ],
      ),
    );
  }
}

Future<void> showDebtSheet(
  BuildContext context, {
  required Ledger ledger,
  String? person,
  String? type,
  int? amount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) =>
        DebtSheet(ledger: ledger, person: person, type: type, amount: amount),
  );
}

class DebtSheet extends StatefulWidget {
  const DebtSheet({
    super.key,
    required this.ledger,
    this.person,
    this.type,
    this.amount,
  });

  final Ledger ledger;
  final String? person;
  final String? type;
  final int? amount;

  @override
  State<DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends State<DebtSheet> {
  late final _person = TextEditingController(text: widget.person ?? '');
  late final _amount = TextEditingController(
    text: switch (widget.amount) {
      null => '',
      final paise when paise % 100 == 0 => '${paise ~/ 100}',
      final paise => (paise / 100).toStringAsFixed(2),
    },
  );
  final _note = TextEditingController();
  late String _type = widget.type ?? 'lent';
  String? _accountId;
  var _date = DateTime.now();
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _person.addListener(() => setState(() {}));
    final accounts = widget.ledger.accounts;
    _accountId = accounts.isEmpty ? null : accounts.first.id;
    loadDefaultAccountId().then((id) {
      if (!mounted || id == null) return;
      if (accounts.any((account) => account.id == id)) {
        setState(() => _accountId = id);
      }
    });
  }

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _known {
    final key = _person.text.trim().toLowerCase();
    return key.isNotEmpty &&
        widget.ledger.debts.people.any(
          (item) => item.name.trim().toLowerCase() == key,
        );
  }

  Future<void> _pickAccount() async {
    final picked = await showAccountPicker(
      context,
      accounts: widget.ledger.accounts,
      bankFor: widget.ledger.bankFor,
      currentId: _accountId,
      title: _type == 'borrowed' || _type == 'got_back'
          ? 'Money came into'
          : 'Money went from',
    );
    if (picked != null && mounted) setState(() => _accountId = picked.id);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final person = _person.text.trim();
    final amount = parseMoney(_amount.text.replaceAll(',', ''));
    if (person.isEmpty) {
      setState(() => _error = 'Who was it?');
      return;
    }
    if (amount == null) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.ledger.saveDebt(
        person: person,
        type: _type,
        amount: amount,
        occurredOn: isoDate(_date),
        accountId: _accountId,
        note: _note.text,
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
    final ledger = widget.ledger;
    final account = ledger.accounts
        .where((item) => item.id == _accountId)
        .firstOrNull;
    final types = _known || widget.type != null
        ? debtTypeLabels.keys.toList()
        : const ['lent', 'borrowed'];
    final suggestions = ledger.debts.people
        .where(
          (item) =>
              _person.text.trim().isEmpty ||
              item.name.toLowerCase().contains(
                _person.text.trim().toLowerCase(),
              ),
        )
        .where(
          (item) =>
              item.name.toLowerCase() != _person.text.trim().toLowerCase(),
        )
        .take(6)
        .toList();
    final today = DateTime.now();
    final isToday = isoDate(_date) == isoDate(today);
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
            const Text(
              'Lend or borrow',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in types)
                  ChoiceChip(
                    label: Text(debtTypeLabels[type]!),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                    showCheckmark: false,
                    selectedColor: _lime,
                    backgroundColor: _card,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: _type == type ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _Input(
              controller: _person,
              hint: 'Friend\'s name',
              icon: LucideIcons.userRound,
              capitalize: true,
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in suggestions)
                    ActionChip(
                      avatar: _Avatar(name: item.name, size: 22),
                      label: Text(item.name),
                      onPressed: () => _person.text = item.name,
                      backgroundColor: _card,
                      side: BorderSide.none,
                      labelStyle: const TextStyle(color: Colors.white),
                      shape: const StadiumBorder(),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _Input(
              controller: _amount,
              hint: 'Amount',
              icon: LucideIcons.indianRupee,
              number: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (account != null)
                  Flexible(
                    child: AccountChip(
                      account: account,
                      bank: ledger.bankFor(account),
                      onTap: _busy ? null : _pickAccount,
                      maxNameWidth: 110,
                      verb: _type == 'borrowed' || _type == 'got_back'
                          ? 'Into'
                          : 'From',
                    ),
                  ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(
                    LucideIcons.calendar,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(isToday ? 'Today' : formatDate(isoDate(_date))),
                  onPressed: _busy ? null : _pickDate,
                  backgroundColor: _field,
                  side: const BorderSide(color: _line),
                  labelStyle: const TextStyle(color: Colors.white),
                  shape: const StadiumBorder(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Input(
              controller: _note,
              hint: 'Note (optional), e.g. for movie tickets',
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
                child: const Text('Save'),
              ),
            ),
          ],
        ),
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
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool number;
  final bool capitalize;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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
