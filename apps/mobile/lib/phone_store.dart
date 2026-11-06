import 'dart:convert';
import 'dart:io';

import 'package:finance_track/models.dart';
import 'package:path_provider/path_provider.dart';

class PhoneStore {
  static Future<void> saveLedger({
    required String month,
    required Summary? summary,
    required List<TransactionItem> transactions,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Budget> budgets,
    required Debts debts,
    required List<Goal> goals,
    required List<Schedule> planned,
  }) async {
    final file = await _file('ledger.json');
    await file.writeAsString(
      jsonEncode({
        'month': month,
        'summary': summary?.toJson(),
        'transactions': transactions.map((item) => item.toJson()).toList(),
        'accounts': accounts.map((item) => item.toJson()).toList(),
        'categories': categories.map((item) => item.toJson()).toList(),
        'budgets': budgets.map((item) => item.toJson()).toList(),
        'debts': debts.toJson(),
        'goals': goals.map((item) => item.toJson()).toList(),
        'planned': planned.map((item) => item.toJson()).toList(),
      }),
    );
  }

  static Future<PhoneLedger?> readLedger() async {
    try {
      final file = await _file('ledger.json');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      final summary = json['summary'];
      return PhoneLedger(
        month: json['month'] as String? ?? '',
        summary: summary is Map<String, dynamic>
            ? Summary.fromJson(summary)
            : null,
        transactions: _list(json['transactions'], TransactionItem.fromJson),
        accounts: _list(json['accounts'], Account.fromJson),
        categories: _list(json['categories'], Category.fromJson),
        budgets: _list(json['budgets'], Budget.fromJson),
        debts: json['debts'] is Map<String, dynamic>
            ? Debts.fromJson(json['debts'] as Map<String, dynamic>)
            : const Debts(),
        goals: _list(json['goals'], Goal.fromJson),
        planned: _list(json['planned'], Schedule.fromJson),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    for (final name in ['ledger.json', 'outbox.json']) {
      final file = await _file(name);
      if (await file.exists()) await file.delete();
    }
  }

  static Future<List<Map<String, dynamic>>> readOutbox() async {
    try {
      final file = await _file('outbox.json');
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString());
      if (json is! List) return [];
      return [
        for (final item in json)
          if (item is Map<String, dynamic>) item,
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> writeOutbox(List<Map<String, dynamic>> items) async {
    final file = await _file('outbox.json');
    await file.writeAsString(jsonEncode(items));
  }

  static Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? localId,
  }) async {
    final items = await readOutbox();
    items.add({
      'method': method,
      'path': path,
      'body': body,
      'localId': localId,
    });
    await writeOutbox(items);
  }

  static Future<File> _file(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$name');
  }
}

class PhoneLedger {
  const PhoneLedger({
    required this.month,
    required this.summary,
    required this.transactions,
    required this.accounts,
    required this.categories,
    required this.budgets,
    required this.debts,
    required this.goals,
    required this.planned,
  });

  final String month;
  final Summary? summary;
  final List<TransactionItem> transactions;
  final List<Account> accounts;
  final List<Category> categories;
  final List<Budget> budgets;
  final Debts debts;
  final List<Goal> goals;
  final List<Schedule> planned;
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return [];
  return [
    for (final item in raw)
      if (item is Map<String, dynamic>) parse(item),
  ];
}
