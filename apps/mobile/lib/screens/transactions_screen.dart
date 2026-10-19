import 'package:finance_track/activity_cache.dart';
import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/period.dart';
import 'package:finance_track/screens/transaction_form_screen.dart';
import 'package:finance_track/widgets/operations_card.dart';
import 'package:finance_track/widgets/spending_card.dart';
import 'package:flutter/material.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, required this.ledger});

  final Ledger ledger;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  var _kind = 'expense';
  var _span = 'month';
  late DateTime _anchor;
  List<TransactionItem> _items = [];
  Object? _error;
  var _ready = false;
  var _request = 0;
  final _cache = ActivityCache();

  Ledger get ledger => widget.ledger;

  @override
  void initState() {
    super.initState();
    final month = ledger.month;
    final today = DateTime.now();
    _anchor = month.year == today.year && month.month == today.month
        ? DateTime(today.year, today.month, today.day)
        : DateTime(month.year, month.month);
    ledger.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ledger.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    final period = historyPeriod(_span, _anchor);
    final from = periodQueryStart(period);
    final to = periodQueryEnd(period);
    final remembered = _cache.memory(from, to);
    if (!mounted) return;
    if (remembered != null) {
      setState(() {
        _items = remembered;
        _ready = true;
        _error = null;
      });
    } else {
      final stored = await _cache.read(from, to);
      if (!mounted || request != _request) return;
      if (stored != null) {
        setState(() {
          _items = stored;
          _ready = true;
          _error = null;
        });
      }
    }
    try {
      final items = await ledger.api.transactions(
        from: from,
        to: to,
        limit: 500,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _ready = true;
        _error = null;
      });
      await _cache.write(from, to, items);
    } on AuthExpiredException {
      await ledger.onUnauthorized?.call();
    } catch (caught) {
      if (!mounted || request != _request) return;
      setState(() {
        _ready = true;
        if (_items.isEmpty) _error = caught;
      });
    }
  }

  void _shift(int delta) {
    setState(() => _anchor = shiftAnchor(_span, _anchor, delta));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final period = historyPeriod(_span, _anchor);
    final slices = spendingSlices(
      kind: _kind,
      categories: ledger.categories,
      transactions: _items,
    );
    final shown = _items.where((item) => item.kind == _kind).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        SpendingCard(
          kind: _kind,
          span: _span,
          previousLabel: period.previousLabel,
          currentLabel: period.label,
          nextLabel: period.nextLabel,
          slices: slices,
          onKind: (kind) => setState(() => _kind = kind),
          onSpan: (span) {
            setState(() => _span = span);
            _load();
          },
          onPrevious: () => _shift(-1),
          onNext: () => _shift(1),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFB4AB)),
            ),
          ),
        if (_ready || shown.isNotEmpty)
          OperationsCard(
            transactions: shown,
            now: DateTime.now(),
            onOpenTransaction: (transaction) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => TransactionFormScreen(
                    ledger: ledger,
                    existing: transaction,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
