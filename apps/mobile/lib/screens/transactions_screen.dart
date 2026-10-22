import 'package:finance_track/activity_cache.dart';
import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/period.dart';
import 'package:finance_track/screens/transaction_form_screen.dart';
import 'package:finance_track/widgets/operations_card.dart';
import 'package:finance_track/widgets/pull_refresh.dart';
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
  List<CategoryTotal> _totals = const [];
  Object? _error;
  var _ready = false;
  var _hasMore = false;
  var _loadingMore = false;
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
    ledger.addListener(_onLedger);
    _load();
  }

  void _onLedger() {
    if (_span == 'month') {
      final month = ledger.month;
      if (_anchor.year != month.year || _anchor.month != month.month) {
        _anchor = DateTime(month.year, month.month);
      }
    }
    _cache.forget();
    _load(preferCache: false);
  }

  @override
  void dispose() {
    ledger.removeListener(_onLedger);
    super.dispose();
  }

  Future<void> _load({bool preferCache = true}) async {
    final request = ++_request;
    final period = historyPeriod(_span, _anchor);
    final from = periodQueryStart(period);
    final to = periodQueryEnd(period);
    if (preferCache) {
      final remembered = _page(_cache.memory(from, to, kind: _kind));
      if (!mounted) return;
      if (remembered != null) {
        setState(() {
          _items = remembered;
          _hasMore = remembered.length == transactionPageSize;
          _ready = true;
          _error = null;
        });
      } else {
        final stored = _page(await _cache.read(from, to, kind: _kind));
        if (!mounted || request != _request) return;
        if (stored != null) {
          setState(() {
            _items = stored;
            _hasMore = stored.length == transactionPageSize;
            _ready = true;
            _error = null;
          });
        }
      }
    }
    try {
      final loaded = await Future.wait([
        ledger.api.transactions(from: from, to: to, limit: transactionPageSize, kind: _kind),
        ledger.api.periodCategories(from: from, to: to),
      ]);
      if (!mounted || request != _request) return;
      final items = loaded[0] as List<TransactionItem>;
      setState(() {
        _items = items;
        _totals = loaded[1] as List<CategoryTotal>;
        _hasMore = items.length == transactionPageSize;
        _ready = true;
        _error = null;
      });
      await _cache.write(from, to, items, kind: _kind);
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

  List<TransactionItem>? _page(List<TransactionItem>? items) {
    if (items == null || items.length > transactionPageSize) return null;
    return items;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || !_ready) return;
    final request = _request;
    final period = historyPeriod(_span, _anchor);
    setState(() => _loadingMore = true);
    try {
      final items = await ledger.api.transactions(
        from: periodQueryStart(period),
        to: periodQueryEnd(period),
        limit: transactionPageSize,
        offset: _items.length,
        kind: _kind,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _items = [..._items, ...items];
        _hasMore = items.length == transactionPageSize;
        _loadingMore = false;
      });
    } on AuthExpiredException {
      await ledger.onUnauthorized?.call();
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    _cache.forget();
    await Future.wait([ledger.refresh(), _load(preferCache: false)]);
  }

  void _shift(int delta) {
    final next = shiftAnchor(_span, _anchor, delta);
    if (_span == 'month') {
      final today = DateTime.now();
      if (DateTime(next.year, next.month).isAfter(DateTime(today.year, today.month))) return;
      ledger.month = DateTime(next.year, next.month);
      ledger.refresh();
      return;
    }
    setState(() => _anchor = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final period = historyPeriod(_span, _anchor);
    final slices = slicesFromTotals(kind: _kind, totals: _totals);
    final shown = _items;
    return NotificationListener<ScrollNotification>(
      onNotification: (notice) {
        if (_nearEnd(notice)) _loadMore();
        return false;
      },
      child: PullRefresh(
      onRefresh: _refresh,
      child: ListView(
      physics: pullPhysics,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        SpendingCard(
          kind: _kind,
          span: _span,
          previousLabel: period.previousLabel,
          currentLabel: period.label,
          nextLabel: period.nextLabel,
          slices: slices,
          onKind: (kind) {
            if (kind == _kind) return;
            setState(() => _kind = kind);
            _load(preferCache: false);
          },
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
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC8F57A)),
              ),
            ),
          ),
      ],
      ),
      ),
    );
  }
}

bool _nearEnd(ScrollNotification notice) {
  if (notice.metrics.axis != Axis.vertical) return false;
  if (notice is! ScrollUpdateNotification && notice is! ScrollEndNotification) return false;
  return notice.metrics.maxScrollExtent > 0 && notice.metrics.extentAfter < 480;
}
