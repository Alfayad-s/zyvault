import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/screens/transaction_form_screen.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await widget.ledger.api.transactions(limit: 500);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on AuthExpiredException {
      await widget.ledger.onUnauthorized?.call();
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _error = caught;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? _items
        : _items.where((item) {
            final note = item.note?.toLowerCase() ?? '';
            return item.categoryName.toLowerCase().contains(query) ||
                item.accountName.toLowerCase().contains(query) ||
                note.contains(query);
          }).toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Search',
            hintStyle: TextStyle(color: Color(0xFF8E8E93)),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('$_error', textAlign: TextAlign.center))
          : matches.isEmpty
          ? const Center(child: Text('No matches'))
          : ListView.separated(
              itemCount: matches.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final transaction = matches[index];
                final sign = transaction.kind == 'expense' ? '-' : '+';
                return ListTile(
                  title: Text(transaction.categoryName),
                  subtitle: Text(
                    '${transaction.accountName} · ${formatDate(transaction.occurredOn)}',
                  ),
                  trailing: Text('$sign${formatMoney(transaction.amount)}'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => TransactionFormScreen(
                          ledger: widget.ledger,
                          existing: transaction,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
