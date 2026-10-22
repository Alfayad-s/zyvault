import 'dart:async';

import 'package:finance_track/activity_cache.dart';
import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/foundation.dart' hide Category, Summary;

const transactionPageSize = 40;

class Ledger extends ChangeNotifier {
  Ledger(this.api, {this.onUnauthorized});

  final FinanceApi api;
  final Future<void> Function()? onUnauthorized;
  Summary? summary;
  List<TransactionItem> recent = [];
  List<TransactionItem> transactions = [];
  List<Account> accounts = [];
  List<Category> categories = [];
  List<Budget> budgets = [];
  Debts debts = const Debts();
  List<Goal> goals = [];
  List<Schedule> planned = [];
  Object? error;
  bool loading = false;
  bool loadingMore = false;
  bool transactionsHasMore = false;
  int _txGeneration = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> clearRecords() async {
    await api.clearRecords();
    await ActivityCache.clear();
    month = DateTime(DateTime.now().year, DateTime.now().month);
    await refresh();
  }

  Future<void> refresh() async {
    final generation = ++_txGeneration;
    loading = summary == null;
    loadingMore = false;
    error = null;
    notifyListeners();
    try {
      await _runSchedules();
      unawaited(loadBanks());
      unawaited(loadCategoryIcons());
      final results = await Future.wait<Object>([
        api.summary(monthKey(month)),
        api.transactions(month: monthKey(month), limit: transactionPageSize),
        api.accounts(),
        api.categories(),
        api.budgets(monthKey(month)),
        api.debts().catchError(_keepDebts),
        api.goals().catchError(_keepGoals),
        api.schedules().catchError(_keepPlanned),
      ]);
      if (generation != _txGeneration) return;
      summary = results[0] as Summary;
      transactions = results[1] as List<TransactionItem>;
      transactionsHasMore = transactions.length == transactionPageSize;
      recent = transactions.take(5).toList();
      accounts = results[2] as List<Account>;
      categories = results[3] as List<Category>;
      budgets = results[4] as List<Budget>;
      debts = results[5] as Debts;
      goals = results[6] as List<Goal>;
      planned = results[7] as List<Schedule>;
      CategoryIcon.remember(categories);
    } on AuthExpiredException {
      await onUnauthorized?.call();
    } catch (caught) {
      if (generation == _txGeneration) error = caught;
    }
    if (generation != _txGeneration) return;
    loading = false;
    notifyListeners();
  }

  Future<void> loadMoreTransactions() async {
    if (loading || loadingMore || !transactionsHasMore) return;
    final generation = _txGeneration;
    final offset = transactions.length;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await api.transactions(
        month: monthKey(month),
        limit: transactionPageSize,
        offset: offset,
      );
      if (generation != _txGeneration) return;
      transactions = [...transactions, ...page];
      transactionsHasMore = page.length == transactionPageSize;
      recent = transactions.take(5).toList();
    } on AuthExpiredException {
      await onUnauthorized?.call();
    } catch (_) {}
    if (generation != _txGeneration) return;
    loadingMore = false;
    notifyListeners();
  }

  Future<Debts> _keepDebts(Object caught) async {
    if (caught is AuthExpiredException) throw caught;
    return debts;
  }

  Future<List<Schedule>> _keepPlanned(Object caught) async {
    if (caught is AuthExpiredException) throw caught;
    return planned;
  }

  /// The earliest upcoming payment, or the earliest plan of any kind if none.
  Schedule? get nextPayment {
    String key(Schedule schedule) =>
        '${schedule.nextOn} ${schedule.atTime ?? '99:99'}';
    final sorted = [...planned]..sort((a, b) => key(a).compareTo(key(b)));
    return sorted.where((schedule) => schedule.kind == 'expense').firstOrNull ??
        sorted.firstOrNull;
  }

  Future<List<Goal>> _keepGoals(Object caught) async {
    if (caught is AuthExpiredException) throw caught;
    return goals;
  }

  Future<void> saveGoal({
    String? id,
    required String name,
    required String icon,
    required int targetAmount,
    String? targetDate,
  }) async {
    await api.saveGoal(
      id: id,
      name: name,
      icon: icon,
      targetAmount: targetAmount,
      targetDate: targetDate,
    );
    await refresh();
  }

  Future<void> deleteGoal(String id) async {
    await api.deleteGoal(id);
    await refresh();
  }

  Future<List<GoalEntry>> goalEntries(String goalId) => api.goalEntries(goalId);

  Future<Goal> addGoalEntry({
    required String goalId,
    required String type,
    required int amount,
    String? note,
  }) async {
    final goal = await api.addGoalEntry(
      goalId: goalId,
      type: type,
      amount: amount,
      occurredOn: isoDate(DateTime.now()),
      note: note,
    );
    await refresh();
    return goal;
  }

  Future<void> deleteGoalEntry(String entryId) async {
    await api.deleteGoalEntry(entryId);
    await refresh();
  }

  Future<int> _runSchedules({bool force = false}) async {
    final now = DateTime.now();
    final last = _schedulesRunAt;
    if (!force &&
        last != null &&
        now.difference(last) < const Duration(minutes: 2)) {
      return 0;
    }
    try {
      final posted = await api.runSchedules(isoDate(now));
      _schedulesRunAt = now;
      return posted;
    } on AuthExpiredException {
      rethrow;
    } catch (_) {
      return 0;
    }
  }

  DateTime? _schedulesRunAt;

  /// Posts plans whose time has come, e.g. when the app returns from a reminder.
  Future<void> catchUpSchedules() async {
    try {
      if (await _runSchedules(force: true) > 0) await refresh();
    } on AuthExpiredException {
      await onUnauthorized?.call();
    }
  }

  Future<List<Schedule>> schedules() => api.schedules();

  Future<void> deleteSchedule(String id) async {
    await api.deleteSchedule(id);
    planned = [
      for (final schedule in planned)
        if (schedule.id != id) schedule,
    ];
    notifyListeners();
  }

  void changeMonth(int delta) {
    final today = DateTime.now();
    final next = DateTime(month.year, month.month + delta);
    if (DateTime(next.year, next.month).isAfter(DateTime(today.year, today.month))) return;
    month = DateTime(next.year, next.month);
    refresh();
  }

  Future<void> createAccount({
    required String name,
    required String type,
    required int openingBalance,
    String? bankId,
  }) async {
    await api.createAccount(
      name: name,
      type: type,
      openingBalance: openingBalance,
      bankId: bankId,
    );
    await refresh();
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required String type,
    required int openingBalance,
    String? bankId,
  }) async {
    await api.updateAccount(
      id: id,
      name: name,
      type: type,
      openingBalance: openingBalance,
      bankId: bankId,
    );
    await refresh();
  }

  Future<void> deleteAccount(String id) async {
    await api.deleteAccount(id);
    await refresh();
  }

  List<CategoryIconOption> categoryIcons = [];

  Future<List<CategoryIconOption>> loadCategoryIcons() async {
    if (categoryIcons.isNotEmpty) return categoryIcons;
    try {
      categoryIcons = await api.categoryIcons();
      CategoryIcon.rememberIcons(categoryIcons);
      notifyListeners();
    } catch (_) {}
    return categoryIcons;
  }

  Future<void> createCategory({
    required String name,
    required String kind,
    required String icon,
  }) async {
    await api.createCategory(name: name, kind: kind, icon: icon);
    await refresh();
  }

  Future<void> updateCategory({
    required String id,
    String? name,
    String? icon,
  }) async {
    await api.updateCategory(id: id, name: name, icon: icon);
    await refresh();
  }

  Future<void> deleteCategory(String id) async {
    await api.deleteCategory(id);
    await refresh();
  }

  Future<void> saveDebt({
    required String person,
    required String type,
    required int amount,
    required String occurredOn,
    String? accountId,
    String? note,
  }) async {
    await api.createDebt(
      person: person,
      type: type,
      amount: amount,
      occurredOn: occurredOn,
      accountId: accountId,
      note: note,
    );
    await refresh();
  }

  Future<void> deleteDebt(String id) async {
    await api.deleteDebt(id);
    await refresh();
  }

  List<Bank> banks = [];

  Future<List<Bank>> loadBanks() async {
    if (banks.isNotEmpty) return banks;
    try {
      banks = await api.banks();
      notifyListeners();
    } catch (_) {}
    return banks;
  }

  Bank? bankFor(Account account) {
    if (account.type != 'bank') return null;
    for (final bank in banks) {
      if (bank.id == account.bankId) return bank;
    }
    if (account.bankId != null) return null;
    final name = account.name.toLowerCase();
    Bank? best;
    for (final bank in banks) {
      if (bank.id == 'other') continue;
      final full = bank.name.toLowerCase();
      final short = RegExp('\\b${RegExp.escape(bank.short.toLowerCase())}\\b');
      final matches = name.contains(full) || short.hasMatch(name);
      if (matches && (best == null || full.length > best.name.length)) {
        best = bank;
      }
    }
    return best;
  }

  Future<void> saveTransaction({
    String? id,
    required String accountId,
    required String categoryId,
    required int amount,
    required String kind,
    required String occurredOn,
    String? note,
  }) async {
    await api.saveTransaction(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      amount: amount,
      kind: kind,
      occurredOn: occurredOn,
      note: note,
    );
    await refresh();
  }

  Future<List<StatementLine>> previewStatement({
    required String fileBase64,
    required String mimeType,
    required String accountId,
    String? password,
  }) {
    return api.previewStatement(
      fileBase64: fileBase64,
      mimeType: mimeType,
      accountId: accountId,
      password: password,
    );
  }

  Future<int> commitStatement({
    required String accountId,
    required List<StatementLine> rows,
  }) async {
    final saved = await api.commitStatement(accountId: accountId, rows: rows);
    if (rows.isNotEmpty) {
      final today = DateTime.now();
      final current = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}';
      final latest = rows.map((row) => row.occurredOn).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      final chosen = rows.any((row) => row.occurredOn.startsWith(current)) ? current : latest;
      final parts = chosen.split('-');
      final year = int.tryParse(parts[0]);
      final monthNumber = int.tryParse(parts[1]);
      if (year != null && monthNumber != null) month = DateTime(year, monthNumber);
    }
    await refresh();
    return saved;
  }

  Future<List<ParsedSpend>> previewBill({
    required String imageBase64,
    required String mimeType,
    required String accountId,
    String? text,
  }) {
    return api.previewBill(
      imageBase64: imageBase64,
      mimeType: mimeType,
      accountId: accountId,
      today: isoDate(DateTime.now()),
      text: text,
    );
  }

  Future<List<AgentResult>> parseAndSave({
    required String text,
    required String accountId,
  }) async {
    final saved = await api.parseTransactions(
      text: text,
      accountId: accountId,
      today: isoDate(DateTime.now()),
    );
    await refresh();
    return saved;
  }

  Future<List<ParsedSpend>> previewText({
    required String text,
    required String accountId,
  }) {
    return api.previewText(
      text: text,
      accountId: accountId,
      today: isoDate(DateTime.now()),
    );
  }

  Future<List<AgentResult>> commitSpends({
    required List<ParsedSpend> items,
    required String accountId,
  }) async {
    final saved = await api.commitTransactions(
      items: items,
      accountId: accountId,
      today: isoDate(DateTime.now()),
    );
    await refresh();
    return saved;
  }

  Future<void> deleteTransaction(String id) async {
    await api.deleteTransaction(id);
    await refresh();
  }

  Future<void> deleteBudget(String id) async {
    await api.deleteBudget(id);
    await refresh();
  }

  Budget? budgetFor(String categoryName) {
    final name = categoryName.toLowerCase();
    return budgets
        .where((budget) => budget.categoryName.toLowerCase() == name)
        .firstOrNull;
  }

  Future<void> saveBudget({
    required String categoryId,
    required int limitAmount,
  }) async {
    await api.saveBudget(
      categoryId: categoryId,
      month: monthKey(month),
      limitAmount: limitAmount,
    );
    await refresh();
  }
}
