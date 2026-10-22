import 'dart:async';

import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/screens/transaction_form_screen.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:finance_track/widgets/pull_refresh.dart';
import 'package:finance_track/widgets/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.ledger});

  final Ledger ledger;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  List<TransactionItem> _items = [];
  Object? _error;
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = false;
  var _request = 0;
  Timer? _typing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _typing?.cancel();
    _query.dispose();
    super.dispose();
  }

  String? get _needle {
    final text = _query.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _load() async {
    final request = ++_request;
    final needle = _needle;
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final items = await widget.ledger.api.transactions(
        limit: transactionPageSize,
        q: needle,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _hasMore = items.length == transactionPageSize;
        _loading = false;
      });
    } on AuthExpiredException {
      await widget.ledger.onUnauthorized?.call();
    } catch (caught) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = caught;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final request = _request;
    final needle = _needle;
    setState(() => _loadingMore = true);
    try {
      final items = await widget.ledger.api.transactions(
        limit: transactionPageSize,
        offset: _items.length,
        q: needle,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _items = [..._items, ...items];
        _hasMore = items.length == transactionPageSize;
        _loadingMore = false;
      });
    } on AuthExpiredException {
      await widget.ledger.onUnauthorized?.call();
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onQueryChanged(String _) {
    _typing?.cancel();
    _typing = Timer(const Duration(milliseconds: 250), _load);
    setState(() {});
  }

  void _search(String text) {
    _query.text = text;
    _query.selection = TextSelection.collapsed(offset: text.length);
    _onQueryChanged(text);
  }

  void _open(TransactionItem transaction) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TransactionFormScreen(ledger: widget.ledger, existing: transaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final matches = _items;
    return Scaffold(
      appBar: AppBar(),
      body: _loading
          ? const ShimmerRows()
          : _error != null
          ? PullRefresh(
              onRefresh: _load,
              child: ListView(
                physics: pullPhysics,
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  Text('$_error', textAlign: TextAlign.center),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: _lime,
                    decoration: InputDecoration(
                      hintText: 'Search for what you want',
                      hintStyle: const TextStyle(color: _muted),
                      prefixIcon: const Icon(LucideIcons.search, color: _muted, size: 20),
                      filled: true,
                      fillColor: _card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _onQueryChanged,
                  ),
                ),
                Expanded(
                  child: PullRefresh(
                    onRefresh: _load,
                    child: query.isEmpty
                        ? _Discover(
                            top: _topSpend(),
                            latest: _items.isEmpty ? null : _items.first,
                            chips: _popular(),
                            onSearch: _search,
                            onOpen: _open,
                          )
                        : matches.isEmpty
                        ? ListView(
                            physics: pullPhysics,
                            children: const [
                              SizedBox(height: 160),
                              Center(
                                child: Text('No matches', style: TextStyle(color: _muted, fontSize: 16)),
                              ),
                            ],
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notice) {
                              if (_nearEnd(notice)) _loadMore();
                              return false;
                            },
                            child: ListView.separated(
                            physics: pullPhysics,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: matches.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index >= matches.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: _lime),
                                    ),
                                  ),
                                );
                              }
                              return _ResultCard(
                                transaction: matches[index],
                                onTap: () => _open(matches[index]),
                              );
                            },
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  CategoryTotal? _topSpend() {
    final expenses = widget.ledger.summary?.categories.where((category) => category.kind == 'expense').toList();
    if (expenses == null || expenses.isEmpty) return null;
    expenses.sort((a, b) => b.total.compareTo(a.total));
    return expenses.first;
  }

  List<String> _popular() {
    final counts = <String, int>{};
    void add(String? raw) {
      final text = raw?.trim() ?? '';
      if (text.length < 2 || text.length > 24) return;
      counts[text] = (counts[text] ?? 0) + 1;
    }

    for (final item in _items) {
      add(item.categoryName);
      add(item.note);
    }
    final ranked = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final chips = ranked.take(8).map((entry) => entry.key).toList();
    if (chips.isNotEmpty) return chips;
    return const ['Salary', 'Rent', 'Food', 'UPI'];
  }
}

class _Discover extends StatelessWidget {
  const _Discover({
    required this.top,
    required this.latest,
    required this.chips,
    required this.onSearch,
    required this.onOpen,
  });

  final CategoryTotal? top;
  final TransactionItem? latest;
  final List<String> chips;
  final ValueChanged<String> onSearch;
  final ValueChanged<TransactionItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: pullPhysics,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (top != null || latest != null)
          SizedBox(
            height: 168,
            child: Row(
              children: [
                if (top != null)
                  Expanded(
                    flex: 2,
                    child: _FeatureCard(
                      onTap: () => onSearch(top!.name),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CategoryIcon(name: top!.name, kind: top!.kind, size: 56),
                          const Spacer(),
                          const Text('Biggest this month', style: TextStyle(color: _muted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            top!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          Text(formatRupees(top!.total), style: const TextStyle(color: _lime, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                if (top != null && latest != null) const SizedBox(width: 12),
                if (latest != null)
                  Expanded(
                    flex: 3,
                    child: _FeatureCard(
                      onTap: () => onOpen(latest!),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Latest payment', style: TextStyle(color: _muted, fontSize: 12)),
                          const Spacer(),
                          Text(
                            latest!.note?.trim().isNotEmpty == true ? latest!.note!.trim() : latest!.categoryName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${latest!.kind == 'expense' ? '-' : '+'}${formatRupees(latest!.amount)}',
                            style: const TextStyle(color: _lime, fontSize: 16),
                          ),
                          Text(formatDate(latest!.occurredOn), style: const TextStyle(color: _muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 28),
        const Text('Popular searches', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in chips)
              ActionChip(
                label: Text(chip),
                labelStyle: const TextStyle(color: Colors.white),
                backgroundColor: _card,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () => onSearch(chip),
              ),
          ],
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.transaction, required this.onTap});

  final TransactionItem transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final note = transaction.note?.trim() ?? '';
    final income = transaction.kind == 'income';
    final title = note.isNotEmpty ? note : transaction.categoryName;
    final detail = [
      if (note.isNotEmpty) transaction.categoryName,
      if (transaction.accountName.isNotEmpty) transaction.accountName,
      formatDate(transaction.occurredOn),
    ].join(' · ');
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CategoryIcon(name: transaction.categoryName, kind: transaction.kind, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${income ? '+' : '-'}${formatRupees(transaction.amount)}',
                style: TextStyle(
                  color: income ? _lime : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

bool _nearEnd(ScrollNotification notice) {
  if (notice.metrics.axis != Axis.vertical) return false;
  if (notice is! ScrollUpdateNotification && notice is! ScrollEndNotification) return false;
  return notice.metrics.maxScrollExtent > 0 && notice.metrics.extentAfter < 480;
}
