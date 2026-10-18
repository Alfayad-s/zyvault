class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    this.bankId,
    int? balance,
  }) : balance = balance ?? openingBalance;

  final String id;
  final String name;
  final String type;
  final int openingBalance;
  final String? bankId;
  final int balance;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      openingBalance: (json['openingBalance'] as num).toInt(),
      bankId: json['bankId'] as String?,
      balance: (json['balance'] as num?)?.toInt(),
    );
  }
}

class Bank {
  const Bank({
    required this.id,
    required this.name,
    required this.short,
    required this.color,
    this.logoUrl,
    this.markUrl,
  });

  final String id;
  final String name;
  final String short;
  final int color;
  final String? logoUrl;
  final String? markUrl;

  factory Bank.fromJson(Map<String, dynamic> json) {
    final hex = (json['color'] as String? ?? '#3A3A3C').replaceAll('#', '');
    return Bank(
      id: json['id'] as String,
      name: json['name'] as String,
      short: json['short'] as String? ?? '',
      color: int.tryParse('FF$hex', radix: 16) ?? 0xFF3A3A3C,
      logoUrl: json['logoUrl'] as String?,
      markUrl: json['markUrl'] as String?,
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.icon,
    this.iconUrl,
    this.custom = false,
  });

  final String id;
  final String name;
  final String kind;
  final String? icon;
  final String? iconUrl;
  final bool custom;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String,
      icon: json['icon'] as String?,
      iconUrl: json['iconUrl'] as String?,
      custom: json['custom'] as bool? ?? false,
    );
  }
}

class CategoryIconOption {
  const CategoryIconOption({required this.key, this.url});

  final String key;
  final String? url;

  factory CategoryIconOption.fromJson(Map<String, dynamic> json) {
    return CategoryIconOption(
      key: json['key'] as String,
      url: json['url'] as String?,
    );
  }
}

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.kind,
    required this.occurredOn,
    required this.note,
  });

  final String id;
  final String accountId;
  final String accountName;
  final String categoryId;
  final String categoryName;
  final int amount;
  final String kind;
  final String occurredOn;
  final String? note;

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      accountName: json['accountName'] as String? ?? '',
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String? ?? '',
      amount: (json['amount'] as num).toInt(),
      kind: json['kind'] as String,
      occurredOn: json['occurredOn'] as String,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'accountName': accountName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'amount': amount,
      'kind': kind,
      'occurredOn': occurredOn,
      'note': note,
    };
  }
}

class SpendSchedule {
  const SpendSchedule({
    required this.repeat,
    required this.dayOfMonth,
    required this.nextOn,
    this.atTime,
  });

  final String repeat;
  final int dayOfMonth;
  final String nextOn;
  final String? atTime;

  bool get monthly => repeat == 'monthly';

  static SpendSchedule? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return SpendSchedule(
      repeat: json['repeat'] as String? ?? 'once',
      dayOfMonth: (json['dayOfMonth'] as num?)?.toInt() ?? 1,
      nextOn: json['nextOn'] as String,
      atTime: json['atTime'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'repeat': repeat,
    'dayOfMonth': dayOfMonth,
    'nextOn': nextOn,
    'atTime': ?atTime,
  };
}

class SpendDebt {
  const SpendDebt({required this.type, required this.person});

  final String type;
  final String person;

  static SpendDebt? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return SpendDebt(
      type: json['type'] as String,
      person: json['person'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'person': person};
}

class SpendGoal {
  const SpendGoal({required this.name, required this.action});

  final String name;
  final String action;

  static SpendGoal? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return SpendGoal(
      name: json['name'] as String,
      action: json['action'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'action': action};
}

class ParsedSpend {
  const ParsedSpend({
    required this.amount,
    required this.kind,
    required this.occurredOn,
    required this.categoryId,
    required this.categoryName,
    required this.note,
    this.merchant,
    this.accountId,
    this.accountName,
    this.schedule,
    this.debt,
    this.goal,
  });

  final int amount;
  final String kind;
  final String occurredOn;
  final String categoryId;
  final String categoryName;
  final String note;
  final String? merchant;
  final String? accountId;
  final String? accountName;
  final SpendSchedule? schedule;
  final SpendDebt? debt;
  final SpendGoal? goal;

  ParsedSpend copyWith({
    int? amount,
    String? kind,
    String? occurredOn,
    String? categoryId,
    String? categoryName,
    String? note,
    String? accountId,
    String? accountName,
  }) {
    return ParsedSpend(
      amount: amount ?? this.amount,
      kind: kind ?? this.kind,
      occurredOn: occurredOn ?? this.occurredOn,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      note: note ?? this.note,
      merchant: merchant,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      schedule: schedule,
      debt: debt,
      goal: goal,
    );
  }

  Map<String, dynamic> toCommitJson() => {
    'amount': amount,
    'kind': kind,
    'categoryId': categoryId,
    'occurredOn': occurredOn,
    if (note.trim().isNotEmpty) 'note': note.trim(),
    'accountId': ?accountId,
    'schedule': ?schedule?.toJson(),
    'debt': ?debt?.toJson(),
    'goal': ?goal?.toJson(),
  };

  factory ParsedSpend.fromJson(Map<String, dynamic> json) {
    return ParsedSpend(
      amount: (json['amount'] as num).toInt(),
      kind: json['kind'] as String? ?? 'expense',
      occurredOn: json['occurredOn'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String? ?? '',
      note: json['note'] as String? ?? json['rawDescription'] as String? ?? '',
      merchant: json['merchant'] as String?,
      accountId: json['accountId'] as String?,
      accountName: json['accountName'] as String?,
      schedule: SpendSchedule.fromJson(json['schedule']),
      debt: SpendDebt.fromJson(json['debt']),
      goal: SpendGoal.fromJson(json['goal']),
    );
  }
}

class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.kind,
    required this.total,
  });

  final String categoryId;
  final String name;
  final String kind;
  final int total;

  factory CategoryTotal.fromJson(Map<String, dynamic> json) {
    return CategoryTotal(
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String,
      total: (json['total'] as num).toInt(),
    );
  }
}

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.month,
    required this.limitAmount,
    this.spent = 0,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final String month;
  final int limitAmount;
  final int spent;

  double get used => limitAmount <= 0 ? 0 : spent / limitAmount;
  int get left => limitAmount - spent;
  bool get over => spent > limitAmount;

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String? ?? '',
      month: json['month'] as String,
      limitAmount: (json['limitAmount'] as num).toInt(),
      spent: (json['spent'] as num?)?.toInt() ?? 0,
    );
  }
}

class Schedule {
  const Schedule({
    required this.id,
    required this.categoryName,
    required this.amount,
    required this.kind,
    required this.note,
    required this.repeat,
    required this.dayOfMonth,
    required this.nextOn,
    this.accountName,
    this.atTime,
  });

  final String id;
  final String? accountName;
  final String? atTime;
  final String categoryName;
  final int amount;
  final String kind;
  final String? note;
  final String repeat;
  final int dayOfMonth;
  final String nextOn;

  bool get monthly => repeat == 'monthly';

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] as String,
      categoryName: json['categoryName'] as String? ?? '',
      amount: (json['amount'] as num).toInt(),
      kind: json['kind'] as String,
      note: json['note'] as String?,
      repeat: json['repeat'] as String,
      dayOfMonth: (json['dayOfMonth'] as num).toInt(),
      nextOn: json['nextOn'] as String,
      accountName: json['accountName'] as String?,
      atTime: json['atTime'] as String?,
    );
  }
}

class AgentResult {
  const AgentResult({
    this.transaction,
    this.schedule,
    this.debt,
    this.goal,
    this.goalEntry,
  });

  final TransactionItem? transaction;
  final Schedule? schedule;
  final DebtEntry? debt;
  final Goal? goal;
  final GoalEntry? goalEntry;

  factory AgentResult.fromJson(Map<String, dynamic> json) {
    final transaction = json['transaction'];
    final schedule = json['schedule'];
    final debt = json['debt'];
    final goal = json['goal'];
    final goalEntry = json['goalEntry'];
    return AgentResult(
      transaction: transaction is Map<String, dynamic>
          ? TransactionItem.fromJson(transaction)
          : null,
      schedule: schedule is Map<String, dynamic>
          ? Schedule.fromJson(schedule)
          : null,
      debt: debt is Map<String, dynamic> && debt['id'] != null
          ? DebtEntry.fromJson(debt)
          : null,
      goal: goal is Map<String, dynamic> && goal['id'] != null
          ? Goal.fromJson(goal)
          : null,
      goalEntry: goalEntry is Map<String, dynamic>
          ? GoalEntry.fromJson(goalEntry)
          : null,
    );
  }
}

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.saved,
    this.icon,
    this.iconUrl,
    this.targetDate,
  });

  final String id;
  final String name;
  final String? icon;
  final String? iconUrl;
  final int targetAmount;
  final String? targetDate;
  final int saved;

  double get progress =>
      targetAmount <= 0 ? 0 : (saved / targetAmount).clamp(0, 1).toDouble();
  bool get reached => saved >= targetAmount;
  int get left => saved >= targetAmount ? 0 : targetAmount - saved;

  /// What to put aside each month to reach the target date, or null.
  int? monthlyNeeded(DateTime today) {
    final date = DateTime.tryParse(targetDate ?? '');
    if (date == null || reached) return null;
    final months =
        (date.year - today.year) * 12 +
        date.month -
        today.month +
        (date.day >= today.day ? 1 : 0);
    if (months <= 0) return left;
    return (left / months).ceil();
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      iconUrl: json['iconUrl'] as String?,
      targetAmount: (json['targetAmount'] as num).toInt(),
      targetDate: json['targetDate'] as String?,
      saved: (json['saved'] as num?)?.toInt() ?? 0,
    );
  }
}

class GoalEntry {
  const GoalEntry({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.occurredOn,
    this.note,
  });

  final String id;
  final String goalId;

  /// Positive when added, negative when taken out.
  final int amount;
  final String occurredOn;
  final String? note;

  factory GoalEntry.fromJson(Map<String, dynamic> json) {
    return GoalEntry(
      id: json['id'] as String,
      goalId: json['goalId'] as String,
      amount: (json['amount'] as num).toInt(),
      occurredOn: json['occurredOn'] as String,
      note: json['note'] as String?,
    );
  }
}

/// lent / borrowed / got_back / paid_back
class DebtEntry {
  const DebtEntry({
    required this.id,
    required this.person,
    required this.type,
    required this.amount,
    required this.occurredOn,
    this.accountId,
    this.accountName,
    this.note,
  });

  final String id;
  final String person;
  final String type;
  final int amount;
  final String occurredOn;
  final String? accountId;
  final String? accountName;
  final String? note;

  bool get moneyIn => type == 'borrowed' || type == 'got_back';

  factory DebtEntry.fromJson(Map<String, dynamic> json) {
    return DebtEntry(
      id: json['id'] as String,
      person: json['person'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toInt(),
      occurredOn: json['occurredOn'] as String,
      accountId: json['accountId'] as String?,
      accountName: json['accountName'] as String?,
      note: json['note'] as String?,
    );
  }
}

class Person {
  const Person({
    required this.name,
    required this.balance,
    required this.lastOn,
  });

  final String name;

  /// Positive when they owe you, negative when you owe them.
  final int balance;
  final String lastOn;

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      name: json['name'] as String,
      balance: (json['balance'] as num).toInt(),
      lastOn: json['lastOn'] as String,
    );
  }
}

class Debts {
  const Debts({this.people = const [], this.entries = const []});

  final List<Person> people;
  final List<DebtEntry> entries;

  int get owedToYou =>
      people.fold(0, (sum, p) => sum + (p.balance > 0 ? p.balance : 0));
  int get youOwe =>
      people.fold(0, (sum, p) => sum + (p.balance < 0 ? -p.balance : 0));

  List<DebtEntry> entriesFor(String person) {
    final key = person.trim().toLowerCase();
    return [
      for (final entry in entries)
        if (entry.person.trim().toLowerCase() == key) entry,
    ];
  }

  factory Debts.fromJson(Map<String, dynamic> json) {
    return Debts(
      people: [
        for (final item in json['people'] as List<dynamic>? ?? [])
          Person.fromJson(item as Map<String, dynamic>),
      ],
      entries: [
        for (final item in json['entries'] as List<dynamic>? ?? [])
          DebtEntry.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class Summary {
  const Summary({
    required this.balance,
    required this.monthIncome,
    required this.monthExpense,
    required this.categories,
  });

  final int balance;
  final int monthIncome;
  final int monthExpense;
  final List<CategoryTotal> categories;

  factory Summary.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'] as List<dynamic>? ?? [];
    return Summary(
      balance: (json['balance'] as num).toInt(),
      monthIncome: (json['monthIncome'] as num).toInt(),
      monthExpense: (json['monthExpense'] as num).toInt(),
      categories: categories
          .map((item) => CategoryTotal.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AskPoint {
  const AskPoint({
    required this.label,
    required this.value,
    this.categoryName,
    this.kind,
  });

  final String label;
  final int value;
  final String? categoryName;
  final String? kind;

  factory AskPoint.fromJson(Map<String, dynamic> json) {
    return AskPoint(
      label: json['label'] as String,
      value: (json['value'] as num).toInt(),
      categoryName: json['categoryName'] as String?,
      kind: json['kind'] as String?,
    );
  }
}

class AskItem {
  const AskItem({
    required this.label,
    required this.value,
    this.detail,
    this.categoryName,
    this.kind,
    this.iconKey,
  });

  final String label;
  final int value;
  final String? detail;
  final String? categoryName;
  final String? kind;
  final String? iconKey;

  factory AskItem.fromJson(Map<String, dynamic> json) {
    return AskItem(
      label: json['label'] as String,
      value: (json['value'] as num).toInt(),
      detail: json['detail'] as String?,
      categoryName: json['categoryName'] as String?,
      kind: json['kind'] as String?,
      iconKey: json['iconKey'] as String?,
    );
  }
}

class AskAnswer {
  const AskAnswer({
    required this.answer,
    required this.intent,
    this.chart = const [],
    this.items = const [],
  });

  final String answer;
  final String intent;
  final List<AskPoint> chart;
  final List<AskItem> items;

  factory AskAnswer.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>? ?? const {};
    return AskAnswer(
      answer: json['answer'] as String? ?? '',
      intent: plan['intent'] as String? ?? 'unknown',
      chart: [
        for (final item in json['chart'] as List<dynamic>? ?? [])
          AskPoint.fromJson(item as Map<String, dynamic>),
      ],
      items: [
        for (final item in json['items'] as List<dynamic>? ?? [])
          AskItem.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}
