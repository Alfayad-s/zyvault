import 'dart:async';
import 'dart:convert';

import 'package:finance_track/activity_cache.dart';
import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/phone_store.dart';
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
  int dataRevision = 0;
  bool offline = false;
  int _txGeneration = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> clearRecords() async {
    await api.clearRecords();
    await ActivityCache.clear();
    await PhoneStore.clear();
    month = DateTime(DateTime.now().year, DateTime.now().month);
    await refresh();
  }

  Future<void> flushPending() async {
    try {
      if (await _flush()) await refresh();
    } on AuthExpiredException {
      await onUnauthorized?.call();
    } catch (_) {}
  }

  Future<void> refresh() async {
    if (summary == null) await _restore();
    final generation = ++_txGeneration;
    loading = summary == null;
    loadingMore = false;
    error = null;
    notifyListeners();
    try {
      await _flush();
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
      offline = false;
      dataRevision++;
      await _persist();
    } on AuthExpiredException {
      await onUnauthorized?.call();
    } catch (caught) {
      if (generation == _txGeneration) {
        error = caught is FinanceException && caught.unavailable
            ? null
            : caught;
        if (caught is FinanceException && caught.unavailable) {
          offline = true;
          if (summary == null && await _restore()) dataRevision++;
        }
      }
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
    final localId = id ?? _localId();
    await _commit(
      send: () => api.saveGoal(
        id: id,
        name: name,
        icon: icon,
        targetAmount: targetAmount,
        targetDate: targetDate,
      ),
      method: id == null ? 'POST' : 'PATCH',
      path: id == null ? '/goals' : '/goals/$id',
      body: {
        'name': name,
        'icon': icon,
        'targetAmount': targetAmount,
        'targetDate': targetDate,
      },
      localId: id == null ? localId : null,
      apply: () {
        final next = Goal(
          id: localId,
          name: name,
          icon: icon,
          targetAmount: targetAmount,
          targetDate: targetDate,
          saved:
              goals.where((goal) => goal.id == localId).firstOrNull?.saved ?? 0,
        );
        goals = [
          next,
          for (final goal in goals)
            if (goal.id != localId) goal,
        ];
      },
    );
  }

  Future<void> deleteGoal(String id) async {
    await _commit(
      send: () async {
        await api.deleteGoal(id);
        return null;
      },
      method: 'DELETE',
      path: '/goals/$id',
      apply: () {
        goals = [
          for (final goal in goals)
            if (goal.id != id) goal,
        ];
      },
    );
  }

  Future<List<GoalEntry>> goalEntries(String goalId) => api.goalEntries(goalId);

  Future<Goal> addGoalEntry({
    required String goalId,
    required String type,
    required int amount,
    String? note,
  }) async {
    final day = isoDate(DateTime.now());
    Goal? saved;
    await _commit(
      send: () async {
        saved = await api.addGoalEntry(
          goalId: goalId,
          type: type,
          amount: amount,
          occurredOn: day,
          note: note,
        );
        return saved;
      },
      method: 'POST',
      path: '/goals/$goalId/entries',
      body: {
        'type': type,
        'amount': amount,
        'occurredOn': day,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      apply: () {
        final sign = type == 'take_out' ? -1 : 1;
        goals = [
          for (final goal in goals)
            if (goal.id == goalId)
              Goal(
                id: goal.id,
                name: goal.name,
                icon: goal.icon,
                iconUrl: goal.iconUrl,
                targetAmount: goal.targetAmount,
                targetDate: goal.targetDate,
                saved: goal.saved + sign * amount,
              )
            else
              goal,
        ];
      },
    );
    return saved ??
        goals.where((goal) => goal.id == goalId).firstOrNull ??
        Goal(id: goalId, name: '', targetAmount: 0, saved: 0);
  }

  Future<void> deleteGoalEntry(String entryId) async {
    await _commit(
      send: () async {
        await api.deleteGoalEntry(entryId);
        return null;
      },
      method: 'DELETE',
      path: '/goals/entries/$entryId',
      apply: () {},
    );
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

  Future<void> saveSchedule({
    String? id,
    required String accountId,
    required String categoryId,
    required int amount,
    required String kind,
    String? note,
    required String repeat,
    required int dayOfMonth,
    required String nextOn,
    String? atTime,
  }) async {
    final body = {
      'accountId': accountId,
      'categoryId': categoryId,
      'amount': amount,
      'kind': kind,
      'note': note,
      'repeat': repeat,
      'dayOfMonth': dayOfMonth,
      'nextOn': nextOn,
      'atTime': atTime,
    };
    final localId = id ?? _localId();
    final account = accounts.where((item) => item.id == accountId).firstOrNull;
    final category = categories.where((item) => item.id == categoryId).firstOrNull;
    await _commit(
      send: () => api.saveSchedule(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        kind: kind,
        note: note,
        repeat: repeat,
        dayOfMonth: dayOfMonth,
        nextOn: nextOn,
        atTime: atTime,
      ),
      method: id == null ? 'POST' : 'PATCH',
      path: id == null ? '/schedules' : '/schedules/$id',
      body: body,
      localId: id == null ? localId : null,
      apply: () {
        final saved = Schedule(
          id: localId,
          accountId: accountId,
          accountName: account?.name,
          categoryId: categoryId,
          categoryName: category?.name ?? '',
          amount: amount,
          kind: kind,
          note: note,
          repeat: repeat,
          dayOfMonth: dayOfMonth,
          nextOn: nextOn,
          atTime: atTime,
        );
        planned = [
          for (final schedule in planned)
            if (schedule.id != localId) schedule,
          saved,
        ];
      },
    );
  }

  Future<void> deleteSchedule(String id) async {
    await _commit(
      send: () async {
        await api.deleteSchedule(id);
        return null;
      },
      method: 'DELETE',
      path: '/schedules/$id',
      apply: () {
        planned = [
          for (final schedule in planned)
            if (schedule.id != id) schedule,
        ];
      },
    );
  }

  void changeMonth(int delta) {
    final today = DateTime.now();
    final next = DateTime(month.year, month.month + delta);
    if (DateTime(
      next.year,
      next.month,
    ).isAfter(DateTime(today.year, today.month))) {
      return;
    }
    month = DateTime(next.year, next.month);
    refresh();
  }

  Future<void> createAccount({
    required String name,
    required String type,
    required int openingBalance,
    String? bankId,
    String? cardKind,
    int? limitAmount,
    int? billDay,
    int? dueDay,
  }) async {
    final localId = _localId();
    final card = type == 'credit';
    await _commit(
      send: () => api.createAccount(
        name: name,
        type: type,
        openingBalance: openingBalance,
        bankId: bankId,
        cardKind: cardKind,
        limitAmount: limitAmount,
        billDay: billDay,
        dueDay: dueDay,
      ),
      method: 'POST',
      path: '/accounts',
      localId: localId,
      body: {
        'name': name,
        'type': type,
        'openingBalance': openingBalance,
        'bankId': bankId,
        'cardKind': cardKind,
        'limitAmount': limitAmount,
        'billDay': billDay,
        'dueDay': dueDay,
      },
      apply: () {
        accounts = [
          ...accounts,
          Account(
            id: localId,
            name: name,
            type: type,
            openingBalance: openingBalance,
            bankId: bankId,
            balance: card ? limitAmount : openingBalance,
            cardKind: cardKind,
            limitAmount: limitAmount,
            billDay: billDay,
            dueDay: dueDay,
            used: card ? 0 : null,
            available: card ? limitAmount : null,
          ),
        ];
        summary = Summary(
          balance: (summary?.balance ?? 0) + (card ? 0 : openingBalance),
          monthIncome: summary?.monthIncome ?? 0,
          monthExpense: summary?.monthExpense ?? 0,
          categories: summary?.categories ?? const [],
          accountChanges: summary?.accountChanges ?? const [],
        );
      },
    );
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required String type,
    required int openingBalance,
    String? bankId,
    String? cardKind,
    int? limitAmount,
    int? billDay,
    int? dueDay,
  }) async {
    await _commit(
      send: () => api.updateAccount(
        id: id,
        name: name,
        type: type,
        openingBalance: openingBalance,
        bankId: bankId,
        cardKind: cardKind,
        limitAmount: limitAmount,
        billDay: billDay,
        dueDay: dueDay,
      ),
      method: 'PATCH',
      path: '/accounts/$id',
      body: {
        'name': name,
        'type': type,
        'openingBalance': openingBalance,
        'bankId': bankId,
        'cardKind': cardKind,
        'limitAmount': limitAmount,
        'billDay': billDay,
        'dueDay': dueDay,
      },
      apply: () {
        accounts = [
          for (final account in accounts)
            if (account.id == id)
              Account(
                id: id,
                name: name,
                type: type,
                openingBalance: openingBalance,
                bankId: bankId,
                cardKind: cardKind ?? account.cardKind,
                limitAmount: limitAmount ?? account.limitAmount,
                billDay: billDay ?? account.billDay,
                dueDay: dueDay ?? account.dueDay,
                used: account.used,
                available: type == 'credit'
                    ? ((limitAmount ?? account.limitAmount ?? 0) - (account.used ?? 0))
                        .clamp(0, limitAmount ?? account.limitAmount ?? 0)
                    : account.available,
                balance: type == 'credit'
                    ? ((limitAmount ?? account.limitAmount ?? 0) - (account.used ?? 0))
                        .clamp(0, limitAmount ?? account.limitAmount ?? 0)
                    : account.balance - account.openingBalance + openingBalance,
              )
            else
              account,
        ];
      },
    );
  }

  Future<void> deleteAccount(String id) async {
    await _commit(
      send: () async {
        await api.deleteAccount(id);
        return null;
      },
      method: 'DELETE',
      path: '/accounts/$id',
      apply: () {
        accounts = [
          for (final account in accounts)
            if (account.id != id) account,
        ];
      },
    );
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
    final localId = _localId();
    await _commit(
      send: () => api.createCategory(name: name, kind: kind, icon: icon),
      method: 'POST',
      path: '/categories',
      localId: localId,
      body: {'name': name, 'kind': kind, 'icon': icon},
      apply: () {
        categories = [
          ...categories,
          Category(
            id: localId,
            name: name,
            kind: kind,
            icon: icon,
            custom: true,
          ),
        ];
      },
    );
  }

  Future<void> updateCategory({
    required String id,
    String? name,
    String? icon,
  }) async {
    await _commit(
      send: () => api.updateCategory(id: id, name: name, icon: icon),
      method: 'PATCH',
      path: '/categories/$id',
      body: {'name': name, 'icon': icon},
      apply: () {
        categories = [
          for (final category in categories)
            if (category.id == id)
              Category(
                id: category.id,
                name: name ?? category.name,
                kind: category.kind,
                icon: icon ?? category.icon,
                iconUrl: category.iconUrl,
                custom: category.custom,
              )
            else
              category,
        ];
      },
    );
  }

  Future<void> deleteCategory(String id) async {
    await _commit(
      send: () async {
        await api.deleteCategory(id);
        return null;
      },
      method: 'DELETE',
      path: '/categories/$id',
      apply: () {
        categories = [
          for (final category in categories)
            if (category.id != id) category,
        ];
      },
    );
  }

  Future<void> saveDebt({
    required String person,
    required String type,
    required int amount,
    required String occurredOn,
    String? accountId,
    String? note,
  }) async {
    final localId = _localId();
    await _commit(
      send: () => api.createDebt(
        person: person,
        type: type,
        amount: amount,
        occurredOn: occurredOn,
        accountId: accountId,
        note: note,
      ),
      method: 'POST',
      path: '/debts',
      localId: localId,
      body: {
        'person': person,
        'type': type,
        'amount': amount,
        'occurredOn': occurredOn,
        'accountId': accountId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      apply: () {
        final account = accounts
            .where((item) => item.id == accountId)
            .firstOrNull;
        final entry = DebtEntry(
          id: localId,
          person: person,
          type: type,
          amount: amount,
          occurredOn: occurredOn,
          accountId: accountId,
          accountName: account?.name,
          note: note,
        );
        final delta = entry.moneyIn ? -amount : amount;
        final people = [
          for (final item in debts.people)
            if (item.name.toLowerCase() != person.toLowerCase()) item,
          Person(
            name: person,
            balance:
                (debts.people
                        .where(
                          (item) =>
                              item.name.toLowerCase() == person.toLowerCase(),
                        )
                        .firstOrNull
                        ?.balance ??
                    0) +
                delta,
            lastOn: occurredOn,
          ),
        ];
        debts = Debts(people: people, entries: [entry, ...debts.entries]);
      },
    );
  }

  Future<void> deleteDebt(String id) async {
    await _commit(
      send: () async {
        await api.deleteDebt(id);
        return null;
      },
      method: 'DELETE',
      path: '/debts/$id',
      apply: () {
        debts = Debts(
          people: debts.people,
          entries: [
            for (final entry in debts.entries)
              if (entry.id != id) entry,
          ],
        );
      },
    );
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
    if (account.type != 'bank' && account.type != 'credit') return null;
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
    String? cardEffect,
    String? cardId,
  }) async {
    final localId = id ?? _localId();
    await _commit(
      send: () => api.saveTransaction(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        kind: kind,
        occurredOn: occurredOn,
        note: note,
        cardEffect: cardEffect,
        cardId: cardId,
      ),
      method: id == null ? 'POST' : 'PATCH',
      path: id == null ? '/transactions' : '/transactions/$id',
      localId: id == null ? localId : null,
      body: {
        'accountId': accountId,
        'categoryId': categoryId,
        'amount': amount,
        'kind': kind,
        'occurredOn': occurredOn,
        'note': note,
        'cardEffect': cardEffect,
        'cardId': cardId,
      },
      apply: () {
        _putTransaction(
          _localTransaction(
            id: localId,
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            kind: kind,
            occurredOn: occurredOn,
            note: note,
            cardEffect: cardEffect,
            cardId: cardId,
          ),
          replaceId: id ?? localId,
        );
      },
    );
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
    var saved = rows.length;
    if (rows.isNotEmpty) {
      final today = DateTime.now();
      final current =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}';
      final latest = rows
          .map((row) => row.occurredOn)
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      final chosen = rows.any((row) => row.occurredOn.startsWith(current))
          ? current
          : latest;
      final parts = chosen.split('-');
      final year = int.tryParse(parts[0]);
      final monthNumber = int.tryParse(parts[1]);
      if (year != null && monthNumber != null) {
        month = DateTime(year, monthNumber);
      }
    }
    await _commit(
      send: () async {
        saved = await api.commitStatement(accountId: accountId, rows: rows);
        return saved;
      },
      method: 'POST',
      path: '/transactions/import/commit',
      body: {
        'accountId': accountId,
        'items': [
          for (final row in rows)
            {
              'accountId': accountId,
              'categoryId': row.categoryId,
              'amount': row.amount,
              'kind': row.kind,
              'occurredOn': row.occurredOn,
              'note': row.note,
            },
        ],
      },
      apply: () {
        for (final row in rows) {
          _putTransaction(
            _localTransaction(
              id: _localId(),
              accountId: accountId,
              categoryId: row.categoryId,
              amount: row.amount,
              kind: row.kind,
              occurredOn: row.occurredOn,
              note: row.note,
            ),
          );
        }
      },
    );
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
    final today = isoDate(DateTime.now());
    final saved = await api.parseTransactions(
      text: text,
      accountId: accountId,
      today: today,
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
    final today = isoDate(DateTime.now());
    final time = clockTime(DateTime.now());
    List<AgentResult> saved = const [];
    await _commit(
      send: () async {
        saved = await api.commitTransactions(
          items: items,
          accountId: accountId,
          today: today,
        );
        return saved;
      },
      method: 'POST',
      path: '/transactions/commit',
      body: {
        'items': [for (final item in items) item.toCommitJson()],
        'accountId': accountId,
        'today': today,
        'time': time,
      },
      apply: () {
        for (final item in items) {
          if (item.schedule != null || item.debt != null || item.goal != null) {
            continue;
          }
          _putTransaction(
            _localTransaction(
              id: _localId(),
              accountId: item.accountId ?? accountId,
              categoryId: item.categoryId,
              amount: item.amount,
              kind: item.kind,
              occurredOn: item.occurredOn,
              note: item.note,
            ),
          );
        }
      },
    );
    return saved;
  }

  Future<void> deleteTransaction(String id) async {
    await _commit(
      send: () async {
        await api.deleteTransaction(id);
        return null;
      },
      method: 'DELETE',
      path: '/transactions/$id',
      apply: () => _dropTransaction(id),
    );
  }

  Future<void> deleteBudget(String id) async {
    await _commit(
      send: () async {
        await api.deleteBudget(id);
        return null;
      },
      method: 'DELETE',
      path: '/budgets/$id',
      apply: () {
        budgets = [
          for (final budget in budgets)
            if (budget.id != id) budget,
        ];
      },
    );
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
    final monthName = monthKey(month);
    final category = categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    await _commit(
      send: () => api.saveBudget(
        categoryId: categoryId,
        month: monthName,
        limitAmount: limitAmount,
      ),
      method: 'PUT',
      path: '/budgets',
      body: {
        'categoryId': categoryId,
        'month': monthName,
        'limitAmount': limitAmount,
      },
      apply: () {
        final localId = _localId();
        budgets = [
          for (final budget in budgets)
            if (budget.categoryId != categoryId || budget.month != monthName)
              budget,
          Budget(
            id: localId,
            categoryId: categoryId,
            categoryName: category?.name ?? '',
            month: monthName,
            limitAmount: limitAmount,
          ),
        ];
      },
    );
  }

  Future<bool> _flush() async {
    final pending = await PhoneStore.readOutbox();
    if (pending.isEmpty) return false;
    final ids = <String, String>{};
    for (var index = 0; index < pending.length; index++) {
      final item = pending[index];
      try {
        final result = await api.dispatch(
          item['method'] as String,
          _swap(item['path'] as String, ids),
          _swapBody(item['body'], ids),
        );
        final localId = item['localId'] as String?;
        if (localId != null && result is Map && result['id'] is String) {
          ids[localId] = result['id'] as String;
        }
      } catch (error) {
        await PhoneStore.writeOutbox(pending.sublist(index));
        rethrow;
      }
    }
    await PhoneStore.writeOutbox(const []);
    return true;
  }

  Future<void> _persist() async {
    await PhoneStore.saveLedger(
      month: monthKey(month),
      summary: summary,
      transactions: transactions,
      accounts: accounts,
      categories: categories,
      budgets: budgets,
      debts: debts,
      goals: goals,
      planned: planned,
    );
  }

  Future<bool> _restore() async {
    final saved = await PhoneStore.readLedger();
    if (saved == null || saved.summary == null) return false;
    summary = saved.summary;
    transactions = saved.transactions;
    transactionsHasMore = transactions.length == transactionPageSize;
    recent = transactions.take(5).toList();
    accounts = saved.accounts;
    categories = saved.categories;
    budgets = saved.budgets;
    debts = saved.debts;
    goals = saved.goals;
    planned = saved.planned;
    CategoryIcon.remember(categories);
    return true;
  }

  Future<void> _commit({
    required Future<Object?> Function() send,
    required void Function() apply,
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? localId,
  }) async {
    try {
      await send();
      await refresh();
    } on AuthExpiredException {
      await onUnauthorized?.call();
    } catch (error) {
      if (error is! FinanceException || !error.unavailable) rethrow;
      apply();
      await PhoneStore.enqueue(
        method: method,
        path: path,
        body: body,
        localId: localId,
      );
      await _persist();
      offline = true;
      dataRevision++;
      notifyListeners();
    }
  }

  String _localId() => 'local-${DateTime.now().microsecondsSinceEpoch}';

  void _putTransaction(TransactionItem item, {String? replaceId}) {
    final id = replaceId ?? item.id;
    final previous = transactions.where((row) => row.id == id).firstOrNull;
    if (previous != null) _moveMoney(previous, remove: true);
    transactions = [
      item,
      for (final row in transactions)
        if (row.id != id) row,
    ];
    recent = transactions.take(5).toList();
    _moveMoney(item, remove: false);
  }

  void _dropTransaction(String id) {
    final previous = transactions.where((row) => row.id == id).firstOrNull;
    if (previous != null) _moveMoney(previous, remove: true);
    transactions = [
      for (final row in transactions)
        if (row.id != id) row,
    ];
    recent = transactions.take(5).toList();
  }

  void _moveMoney(TransactionItem item, {required bool remove}) {
    final spend = item.cardEffect == 'spend';
    final payment = item.cardEffect == 'payment';
    final sign = item.kind == 'income' ? 1 : -1;
    final delta = remove ? -sign * item.amount : sign * item.amount;
    final cashDelta = spend ? 0 : delta;
    final current = summary;
    final monthName = monthKey(month);
    final inMonth = item.occurredOn.startsWith(monthName);
    final count = payment ? 0 : 1;
    summary = Summary(
      balance: (current?.balance ?? 0) + cashDelta,
      monthIncome:
          (current?.monthIncome ?? 0) +
          (inMonth && item.kind == 'income'
              ? count * (remove ? -item.amount : item.amount)
              : 0),
      monthExpense:
          (current?.monthExpense ?? 0) +
          (inMonth && item.kind == 'expense'
              ? count * (remove ? -item.amount : item.amount)
              : 0),
      categories: current?.categories ?? const [],
      accountChanges: current?.accountChanges ?? const [],
    );
    accounts = [
      for (final account in accounts)
        if (spend && account.id == item.accountId)
          _shiftCard(account, remove ? -item.amount : item.amount)
        else if (account.id == item.accountId)
          account.copyWith(balance: account.balance + cashDelta)
        else if (payment && account.id == item.cardId)
          _shiftCard(account, remove ? item.amount : -item.amount)
        else
          account,
    ];
  }

  Account _shiftCard(Account account, int usedChange) {
    final cap = account.limitAmount ?? 0;
    final used = ((account.used ?? 0) + usedChange).clamp(0, cap);
    final available = cap - used;
    return account.copyWith(balance: available, used: used, available: available);
  }

  TransactionItem _localTransaction({
    required String id,
    required String accountId,
    required String categoryId,
    required int amount,
    required String kind,
    required String occurredOn,
    String? note,
    String? cardEffect,
    String? cardId,
  }) {
    final account = accounts.where((item) => item.id == accountId).firstOrNull;
    final category = categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    return TransactionItem(
      id: id,
      accountId: accountId,
      accountName: account?.name ?? '',
      categoryId: categoryId,
      categoryName: category?.name ?? '',
      amount: amount,
      kind: kind,
      occurredOn: occurredOn,
      note: note,
      cardEffect: cardEffect,
      cardId: cardId,
    );
  }

  String _swap(String value, Map<String, String> ids) {
    var out = value;
    for (final entry in ids.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return out;
  }

  Map<String, dynamic>? _swapBody(Object? body, Map<String, String> ids) {
    if (body is! Map) return null;
    final encoded = _swap(jsonEncode(body), ids);
    final decoded = jsonDecode(encoded);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}
