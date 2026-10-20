import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/celebration.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/screens/ask_sheet.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:file_picker/file_picker.dart';
import 'package:finance_track/screens/bill_review.dart';
import 'package:finance_track/screens/budgets_section.dart';
import 'package:finance_track/screens/people_section.dart';
import 'package:finance_track/screens/review_sheet.dart';
import 'package:finance_track/widgets/account_chip.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:finance_track/widgets/thinking_orb.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpendLine {
  const SpendLine({
    required this.amount,
    required this.reason,
    required this.categoryName,
    required this.kind,
    this.occurredOn,
    this.accountName,
  });

  final int amount;
  final String reason;
  final String categoryName;
  final String kind;
  final DateTime? occurredOn;
  final String? accountName;
}

final _paymentWords = RegExp(
  r'\b(gpay|google pay|phonepe|upi|via|by|card|debit|credit card|account|acc|a/c)\b',
);

({Account? account, String text}) accountInText(
  String text,
  List<Account> accounts,
  Bank? Function(Account account) bankFor,
) {
  if (accounts.length < 2) return (account: null, text: text);
  final lower = text.toLowerCase();
  final found = <Account, RegExpMatch>{};
  for (final account in accounts) {
    final bank = bankFor(account);
    final words = <String>{
      account.name.toLowerCase(),
      if (account.type == 'cash') 'cash',
      if (bank != null && bank.id != 'other') ...[
        bank.name.toLowerCase(),
        bank.short.toLowerCase(),
      ],
    }.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final word in words) {
      final match = RegExp('\\b${RegExp.escape(word)}\\b').firstMatch(lower);
      if (match != null) {
        found[account] = match;
        break;
      }
    }
  }
  if (found.length != 1) return (account: null, text: text);
  final MapEntry(key: account, value: match) = found.entries.single;
  final rest = text
      .replaceRange(match.start, match.end, ' ')
      .replaceAll(_paymentWords, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return (account: account, text: rest);
}

const _expenseWords = <String, List<String>>{
  'Food': [
    'food',
    'lunch',
    'dinner',
    'breakfast',
    'restaurant',
    'hotel',
    'swiggy',
    'zomato',
    'pizza',
    'biryani',
    'burger',
    'shawarma',
    'porotta',
    'parotta',
    'meal',
    'meals',
    'oonu',
    'ഭക്ഷണം',
    'ബിരിയാണി',
    'ഊണ്',
    'ഹോട്ടൽ',
    'പിസ്സ',
  ],
  'Groceries': [
    'grocery',
    'groceries',
    'vegetables',
    'veggies',
    'milk',
    'fruits',
    'supermarket',
    'bigbasket',
    'blinkit',
    'zepto',
    'dmart',
    'kirana',
    'pachakkari',
    'പച്ചക്കറി',
    'പാൽ',
  ],
  'Chai & coffee': [
    'chai',
    'tea',
    'coffee',
    'cafe',
    'snack',
    'snacks',
    'juice',
    'bakery',
    'starbucks',
    'chaya',
    'ചായ',
    'കാപ്പി',
    'പലഹാര',
  ],
  'Transport': [
    'transport',
    'uber',
    'ola',
    'rapido',
    'cab',
    'taxi',
    'bus',
    'metro',
    'train',
    'auto',
    'rickshaw',
    'parking',
    'toll',
    'ride',
    'ബസ്',
    'ഓട്ടോ',
    'ടാക്സി',
    'ട്രെയിൻ',
    'മെട്രോ',
  ],
  'Fuel': ['petrol', 'fuel', 'diesel', 'cng', 'പെട്രോൾ', 'ഡീസൽ'],
  'Travel': [
    'flight',
    'flights',
    'trip',
    'holiday',
    'vacation',
    'tour',
    'makemytrip',
    'goibibo',
    'airbnb',
    'oyo',
    'resort',
  ],
  'Rent': ['rent', 'pg', 'hostel', 'vaadaka', 'vadaka', 'വാടക'],
  'Home': [
    'furniture',
    'repair',
    'plumber',
    'electrician',
    'carpenter',
    'utensils',
    'decor',
    'maid',
    'cleaning',
  ],
  'Bills': [
    'bill',
    'bills',
    'electricity',
    'electric',
    'water',
    'wifi',
    'internet',
    'gas',
    'cylinder',
    'broadband',
    'dth',
    'kseb',
    'current',
    'ബിൽ',
    'കറന്റ്',
    'വൈദ്യുതി',
  ],
  'Recharge': [
    'recharge',
    'jio',
    'airtel',
    'prepaid',
    'postpaid',
    'data pack',
    'റീചാർജ്',
  ],
  'Subscriptions': [
    'subscription',
    'netflix',
    'spotify',
    'prime',
    'hotstar',
    'youtube premium',
    'icloud',
    'chatgpt',
  ],
  'Shopping': [
    'shopping',
    'shop',
    'clothes',
    'cloth',
    'clothing',
    'amazon',
    'flipkart',
    'myntra',
    'meesho',
    'ajio',
    'mall',
    'shoes',
    'shoe',
    'dress',
    'thuni',
    'തുണി',
    'ഡ്രസ്സ്',
    'ഷൂസ്',
  ],
  'Personal care': [
    'salon',
    'haircut',
    'hair cut',
    'barber',
    'spa',
    'parlour',
    'parlor',
    'cosmetics',
    'makeup',
    'മുടി',
  ],
  'Health': [
    'doctor',
    'medicine',
    'medicines',
    'pharmacy',
    'hospital',
    'clinic',
    'tablets',
    'lab test',
    'checkup',
    'dentist',
    'dental',
    'മരുന്ന്',
    'ആശുപത്രി',
  ],
  'Insurance': ['insurance', 'lic', 'policy'],
  'Education': [
    'school',
    'college',
    'tuition',
    'fees',
    'fee',
    'course',
    'books',
    'exam',
    'coaching',
    'udemy',
  ],
  'Kids': ['kids', 'toys', 'toy', 'diaper', 'diapers', 'baby', 'daycare'],
  'Pets': ['pet', 'pets', 'dog', 'cat', 'vet', 'pet food'],
  'Entertainment': [
    'movie',
    'movies',
    'cinema',
    'concert',
    'game',
    'games',
    'bookmyshow',
    'party',
    'outing',
    'സിനിമ',
  ],
  'Gifts': ['gift', 'gifts', 'present', 'donation', 'offering'],
  'EMI': ['emi', 'loan emi', 'credit card'],
  'Investments': [
    'sip',
    'mutual fund',
    'mutual funds',
    'stocks',
    'shares',
    'gold',
    'fd',
    'zerodha',
    'groww',
    'investment',
  ],
};

const _incomeWords = <String, List<String>>{
  'Salary': [
    'salary',
    'salaries',
    'paycheck',
    'wage',
    'wages',
    'bonus',
    'shambalam',
    'ശമ്പളം',
  ],
  'Business': ['business', 'sales', 'profit'],
  'Freelance': ['freelance', 'client', 'gig', 'consulting'],
  'Interest': ['interest', 'dividend'],
  'Refund': ['refund', 'cashback', 'reversal'],
  'Rental income': ['tenant', 'rental'],
  'Other income': ['income'],
};

const _incomingAs = {'Gifts': 'Gift received', 'Rent': 'Rental income'};

const _broaderCategories = {
  'Groceries': 'Food',
  'Chai & coffee': 'Food',
  'Fuel': 'Transport',
  'Travel': 'Transport',
  'Recharge': 'Bills',
  'Subscriptions': 'Bills',
  'Insurance': 'Bills',
  'EMI': 'Bills',
  'Entertainment': 'Shopping',
  'Personal care': 'Shopping',
  'Home': 'Shopping',
  'Gifts': 'Shopping',
  'Business': 'Other income',
  'Freelance': 'Other income',
  'Interest': 'Other income',
  'Refund': 'Other income',
  'Gift received': 'Other income',
  'Rental income': 'Other income',
};

final _amountPattern = RegExp(
  r'(?<![\w.])(\d[\d,]*(?:\.\d+)?)\s?(k|thousand|lakhs?|lacs?|l|crores?|cr)?(?![a-z\d])',
);

const _multipliers = <String, int>{
  'k': 1000,
  'thousand': 1000,
  'l': 100000,
  'lac': 100000,
  'lacs': 100000,
  'lakh': 100000,
  'lakhs': 100000,
  'cr': 10000000,
  'crore': 10000000,
  'crores': 10000000,
};

const _incomeVerbs = [
  'got',
  'get',
  'received',
  'receive',
  'earned',
  'credited',
  'income',
  'kitti',
  'kittiyathu',
  'കിട്ടി',
];

final _fillerPattern = RegExp(
  r'\b(spent|spend|paid|pay|gave|bought|got|get|received|receive|earned|credited|'
  r'rupees|rupee|rs|inr|on|for|at|to|the|a|an|of|my|me|i|this|that|today|yesterday|'
  r'last night|this month|month|and|then)\b',
);

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

final _monthWord =
    r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';

final _dayMonthPattern = RegExp(
  '\\b(?:on\\s+)?(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?$_monthWord\\b',
);
final _monthDayPattern = RegExp(
  '\\b(?:on\\s+)?$_monthWord\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b',
);
final _ordinalPattern = RegExp(
  r'\b(?:on\s+)?(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)\b(?:\s+(?:of\s+)?(this|last)\s+month)?',
);
final _relativePattern = RegExp(
  r'\b(day before yesterday|parso|mininjaannu|yesterday|last night|kal raat|innale|kal)\b',
);

final _malayalamDayPattern = RegExp(
  r'(?<!\d)(\d{1,2})\s?-?\s?(?:ന്|നു|ആം തീയതി|ാം തീയതി)',
);

const _malayalamRelative = {'മിനിഞ്ഞാന്ന്': 2, 'ഇന്നലെ': 1};

({DateTime? date, String rest}) _takeDate(String text, DateTime today) {
  DateTime? valid(int year, int month, int day) {
    final date = DateTime(year, month, day);
    return date.day == day ? date : null;
  }

  DateTime? inPast(int month, int day) {
    final date = valid(today.year, month, day);
    if (date == null || !date.isAfter(today)) return date;
    return valid(today.year - 1, month, day);
  }

  String without(RegExpMatch match) =>
      text.replaceRange(match.start, match.end, ' ');

  final dayMonth = _dayMonthPattern.firstMatch(text);
  if (dayMonth != null) {
    final day = int.parse(dayMonth.group(1)!);
    final month = _months[dayMonth.group(2)!.substring(0, 3)]!;
    return (date: inPast(month, day), rest: without(dayMonth));
  }
  final monthDay = _monthDayPattern.firstMatch(text);
  if (monthDay != null) {
    final month = _months[monthDay.group(1)!.substring(0, 3)]!;
    final day = int.parse(monthDay.group(2)!);
    return (date: inPast(month, day), rest: without(monthDay));
  }
  final ordinal = _ordinalPattern.firstMatch(text);
  if (ordinal != null) {
    final day = int.parse(ordinal.group(1)!);
    final lastMonth = ordinal.group(2) == 'last';
    var date = valid(today.year, today.month - (lastMonth ? 1 : 0), day);
    if (date != null && date.isAfter(today)) {
      date = valid(today.year, today.month - 1, day);
    }
    return (date: date, rest: without(ordinal));
  }
  final malayalamDay = _malayalamDayPattern.firstMatch(text);
  if (malayalamDay != null) {
    final day = int.parse(malayalamDay.group(1)!);
    var date = valid(today.year, today.month, day);
    if (date != null && date.isAfter(today)) {
      date = valid(today.year, today.month - 1, day);
    }
    return (date: date, rest: without(malayalamDay));
  }
  for (final entry in _malayalamRelative.entries) {
    final index = text.indexOf(entry.key);
    if (index >= 0) {
      return (
        date: today.subtract(Duration(days: entry.value)),
        rest: text.replaceRange(index, index + entry.key.length, ' '),
      );
    }
  }
  final relative = _relativePattern.firstMatch(text);
  if (relative != null) {
    final back =
        const {'day before yesterday': 2, 'parso': 2, 'mininjaannu': 2}[relative
            .group(1)] ??
        1;
    return (
      date: today.subtract(Duration(days: back)),
      rest: text.replaceRange(relative.start, relative.end, ' '),
    );
  }
  return (date: null, rest: text);
}

List<SpendLine> parseSpendLines(String text, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final taken = _takeDate(
    text
        .toLowerCase()
        .replaceAll('₹', ' ')
        .replaceAll(RegExp(r'\brs\.?(?=\s*\d)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim(),
    today,
  );
  final normalized = taken.rest.replaceAll(RegExp(r'\s+'), ' ').trim();
  final occurredOn = taken.date ?? today;
  final amounts = _amountPattern.allMatches(normalized).toList();
  final lines = <SpendLine>[];
  for (var index = 0; index < amounts.length; index++) {
    final match = amounts[index];
    final amount = _amount(match);
    final after = normalized.substring(
      match.end,
      index + 1 < amounts.length ? amounts[index + 1].start : normalized.length,
    );
    final before = normalized.substring(
      index == 0 ? 0 : amounts[index - 1].end,
      match.start,
    );
    final reasonAfter = _cleanReason(after);
    final reason = reasonAfter.isNotEmpty ? reasonAfter : _cleanReason(before);
    if (amount == null || reason.isEmpty) continue;
    final context = '$before $after';
    final incoming = _incomeVerbs.any((verb) => _wordIndex(context, verb) >= 0);
    var categoryName = categoryNameFor(reason);
    var kind = _incomeWords.containsKey(categoryName) ? 'income' : 'expense';
    if (incoming && kind == 'expense') {
      kind = 'income';
      categoryName = _incomingAs[categoryName] ?? 'Other income';
    }
    lines.add(
      SpendLine(
        amount: amount,
        reason: reason,
        categoryName: categoryName,
        kind: kind,
        occurredOn: occurredOn,
      ),
    );
  }
  return lines;
}

int? _amount(RegExpMatch match) {
  final base = parseMoney(match.group(1)!.replaceAll(',', ''));
  if (base == null) return null;
  return base * (_multipliers[match.group(2)] ?? 1);
}

final _quickPattern = RegExp(
  r'^(?:₹|rs\.?)?\s*\d[\d,]*(?:\.\d+)?\s?(?:k|thousand|lakhs?|lacs?|l|crores?|cr)?\s+([a-z][a-z ]*)$',
);

bool isQuickSpend(String text, {Iterable<String> categoryNames = const []}) {
  final normalized = text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final match = _quickPattern.firstMatch(normalized);
  if (match == null) return false;
  final reason = match.group(1)!.trim();
  if (reason.split(' ').length > 3) return false;
  if (_relativePattern.hasMatch(reason)) return false;
  if (categoryNames.any((name) => name.toLowerCase() == reason)) return true;
  return categoryNameFor(reason) != 'Other';
}

double typeFontSize(int length) {
  if (length <= 16) return 40;
  if (length <= 32) return 34;
  if (length <= 60) return 28;
  return 24;
}

SpendLine? parseSpendLine(String text, {DateTime? now}) {
  final lines = parseSpendLines(text, now: now);
  if (lines.isEmpty) return null;
  return lines.first;
}

String categoryNameFor(String reason) {
  final text = reason.toLowerCase();
  String? bestName;
  var bestLength = 0;
  var bestIndex = 1 << 30;
  for (final entry in {..._expenseWords, ..._incomeWords}.entries) {
    for (final word in entry.value) {
      final index = _wordIndex(text, word);
      if (index < 0) continue;
      if (word.length > bestLength ||
          (word.length == bestLength && index < bestIndex)) {
        bestName = entry.key;
        bestLength = word.length;
        bestIndex = index;
      }
    }
  }
  return bestName ?? 'Other';
}

String spendMessage(SpendLine spend) {
  final verb = spend.kind == 'income' ? 'received' : 'spend';
  final where = spend.accountName == null
      ? ''
      : ' ${spend.kind == 'income' ? 'to' : 'from'} ${spend.accountName}';
  final message =
      '$verb ${formatRupees(spend.amount)} for ${spend.reason}$where';
  final day = spend.occurredOn == null ? null : isoDate(spend.occurredOn!);
  if (day == null || day == isoDate(DateTime.now())) return message;
  return '$message on ${formatDate(day)}';
}

final _schedulePattern = RegExp(
  r'\b(every|each|monthly|all month|next month|next week|will|going to|have to|'
  r'schedule|remind|from next|ella maasavum|ellaa maasavum|ella masavum|'
  r'adutha maasam|adutha masam|kittum|tharum|kodukkanam|varum)\b',
);

const _malayalamSchedule = [
  'എല്ലാ മാസവും',
  'ഓരോ മാസവും',
  'അടുത്ത മാസം',
  'കിട്ടും',
  'തരും',
  'കൊടുക്കണം',
  'അടയ്ക്കണം',
];

final _clockPattern = RegExp(
  r'\b\d{1,2}([:.]\d{2})?\s?(am|pm)\b|\b(tonight|tomorrow|baje|manikku)\b',
);

bool looksScheduled(String text) {
  final lower = text.toLowerCase();
  return _schedulePattern.hasMatch(lower) ||
      _clockPattern.hasMatch(lower) ||
      _malayalamSchedule.any(lower.contains);
}

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

String scheduleMessage(Schedule schedule, {String? accountName}) {
  final amount = formatRupees(schedule.amount);
  final what = schedule.note ?? schedule.categoryName;
  final verb = schedule.kind == 'income' ? 'get' : 'pay';
  final where = accountName == null
      ? ''
      : ' ${schedule.kind == 'income' ? 'in' : 'from'} $accountName';
  final at = schedule.atTime == null
      ? ''
      : ' at ${formatClock(schedule.atTime!)}';
  if (schedule.monthly) {
    return 'every month on the ${_ordinal(schedule.dayOfMonth)}$at: $verb $amount for $what$where';
  }
  final day = schedule.nextOn == isoDate(DateTime.now())
      ? 'today'
      : 'on ${formatDate(schedule.nextOn)}';
  return 'scheduled: $verb $amount for $what$where $day$at';
}

final _loanPattern = RegExp(
  r'\b(lent|lend|loan|borrow|borrowed|udhaar|udhar|kadam|paid back|pay back|'
  r'paid me back|returned|thirichu)\b',
);

bool looksLikeLoan(String text) {
  final lower = text.toLowerCase();
  return _loanPattern.hasMatch(lower) ||
      lower.contains('കടം') ||
      lower.contains('തിരിച്ചു');
}

final _goalVerbs = RegExp(
  r'\b(add|added|save|saved|saving|put|keep|kept|aside|maati|mati|vechu|'
  r'take out|took out|took|withdraw|withdrew|used|fund)\b',
);

bool mentionsGoal(String text, List<Goal> goals) {
  final lower = text.toLowerCase();
  if (!_goalVerbs.hasMatch(lower)) return false;
  return goals.any((goal) {
    final name = goal.name.toLowerCase().trim();
    return name.isNotEmpty && lower.contains(name);
  });
}

String goalMessage(Goal goal, GoalEntry? entry) {
  final amount = entry == null ? '' : formatRupees(entry.amount.abs());
  final progress =
      '${formatRupees(goal.saved)} of ${formatRupees(goal.targetAmount)}';
  if (entry != null && entry.amount < 0) {
    return 'took $amount out of ${goal.name} · ${formatRupees(goal.saved)} saved';
  }
  if (goal.reached) return 'added $amount to ${goal.name} · goal reached!';
  return 'added $amount to ${goal.name} · $progress';
}

String debtMessage(DebtEntry debt, {String? accountName}) {
  final amount = formatRupees(debt.amount);
  final where = accountName == null
      ? ''
      : ' ${debt.moneyIn ? 'to' : 'from'} $accountName';
  return switch (debt.type) {
    'lent' => 'lent $amount to ${debt.person}$where',
    'borrowed' => 'borrowed $amount from ${debt.person}$where',
    'got_back' => '${debt.person} paid back $amount$where',
    _ => 'paid back $amount to ${debt.person}$where',
  };
}

String spendMessages(List<SpendLine> spends) {
  return spends.map(spendMessage).join('\n');
}

String _cleanReason(String raw) {
  return raw
      .replaceAll(RegExp(r'[,.;:!?]'), ' ')
      .replaceAll(_fillerPattern, ' ')
      .replaceAll(RegExp(r'\b(roopa|rupa|koduthu|vangi|chilavayi)\b'), ' ')
      .replaceAll(
        RegExp(r'(രൂപ|കൊടുത്തു|വാങ്ങി|ചെലവായി|അടച്ചു|കിട്ടി)\S*'),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

final _latinWord = RegExp(r'^[a-z0-9 ]+$');

int _wordIndex(String text, String word) {
  if (!_latinWord.hasMatch(word)) return text.indexOf(word);
  final match = RegExp('\\b${RegExp.escape(word)}\\b').firstMatch(text);
  return match?.start ?? -1;
}

Category? categoryFor(SpendLine spend, List<Category> categories) {
  final sameKind = categories.where((category) => category.kind == spend.kind);
  Category? named(String? name) {
    if (name == null) return null;
    for (final category in sameKind) {
      if (category.name.toLowerCase() == name.toLowerCase()) return category;
    }
    return null;
  }

  final reason = spend.reason.toLowerCase();
  for (final category in sameKind) {
    if (category.custom &&
        _wordIndex(reason, category.name.toLowerCase()) >= 0) {
      return category;
    }
  }
  return named(spend.categoryName) ??
      named(_broaderCategories[spend.categoryName]) ??
      named(spend.kind == 'income' ? 'Other income' : 'Other') ??
      (sameKind.isEmpty ? null : sameKind.first);
}

const _voiceLanguageKey = 'voice_language';

class TypePage extends StatefulWidget {
  const TypePage({super.key, required this.ledger, this.startVoice = false});

  final Ledger ledger;

  /// Starts listening as soon as the page opens, e.g. from the home widget.
  final bool startVoice;

  @override
  State<TypePage> createState() => _TypePageState();
}

class _TypePageState extends State<TypePage>
    with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  late final AnimationController _fill;
  String? _message;
  String? _error;
  var _saving = false;
  Uint8List? _billBytes;
  List<ParsedSpend>? _drafts;
  final _speech = SpeechToText();
  var _speechReady = false;
  var _listening = false;
  var _level = 0.0;
  var _voiceLanguage = 'en';
  var _review = true;
  String? _accountId;
  String? _payee;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _loadVoiceLanguage().then((_) {
      if (widget.startVoice && mounted) _toggleVoice();
    });
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      Celebration.warmUp();
    }
  }

  Future<void> _loadVoiceLanguage() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_voiceLanguageKey);
      final account = await loadDefaultAccountId();
      final review = await loadReviewBeforeSave();
      if (!mounted) return;
      setState(() {
        if (saved != null) _voiceLanguage = saved;
        _accountId = account;
        _review = review;
      });
    } catch (_) {}
  }

  Future<void> _chooseAccount() async {
    final accounts = widget.ledger.accounts;
    if (accounts.isEmpty || _saving) return;
    final picked = await showAccountPicker(
      context,
      accounts: accounts,
      bankFor: widget.ledger.bankFor,
      currentId: _account()?.id,
    );
    if (picked == null || !mounted) return;
    setState(() => _accountId = picked.id);
    await saveDefaultAccountId(picked.id);
  }

  Future<void> _paySomeone() async {
    if (_saving) return;
    final Contact? contact;
    try {
      contact = await FlutterNativeContactPicker().selectContact();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open contacts');
      return;
    }
    if (!mounted || contact == null) return;
    final name = contact.fullName?.trim() ?? '';
    if (name.isEmpty) {
      setState(() => _error = 'That contact has no name');
      return;
    }
    setState(() {
      _payee = name;
      _error = null;
    });
    await showDebtSheet(
      context,
      ledger: widget.ledger,
      person: name,
      type: 'lent',
      accountId: _account()?.id,
    );
  }

  Future<void> _switchVoiceLanguage() async {
    if (_listening) return;
    final next = _voiceLanguage == 'ml' ? 'en' : 'ml';
    setState(() {
      _voiceLanguage = next;
      _error = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_voiceLanguageKey, next);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_listening) _speech.cancel();
    _text.dispose();
    _fill.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (_saving || _message != null) return;
    if (_listening) {
      await _speech.stop();
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_speechReady) {
      final problem = await _startSpeech();
      if (!mounted) return;
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }
    final malayalam = _voiceLanguage == 'ml';
    final wanted = malayalam ? 'ml_in' : 'en_in';
    final locales = await _speech.locales();
    String? localeId;
    for (final locale in locales) {
      if (locale.localeId.replaceAll('-', '_').toLowerCase() == wanted) {
        localeId = locale.localeId;
      }
    }
    if (!mounted) return;
    if (localeId == null && malayalam) {
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        setState(
          () => _error = 'Malayalam voice is not available on this iPhone',
        );
        return;
      }
      localeId = 'ml_IN';
    }
    _text.clear();
    setState(() {
      _listening = true;
      _level = 0;
      _error = null;
    });
    await _speech.listen(
      onResult: _onSpeech,
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _level = ((level + 2) / 12).clamp(0, 1));
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
        localeId: localeId,
        contextualPhrases: const [
          'rupees',
          'lakh',
          'Swiggy',
          'Zomato',
          'Uber',
          'Ola',
          'Rapido',
          'salary',
          'rent',
          'petrol',
          'recharge',
        ],
      ),
    );
  }

  Future<String?> _startSpeech() async {
    for (final lookup in [false, true]) {
      try {
        _speechReady = await _speech.initialize(
          onError: _onSpeechError,
          onStatus: _onSpeechStatus,
          debugLogging: kDebugMode,
          options: [
            SpeechToText.androidNoBluetooth,
            SpeechToText.iosNoBluetooth,
            if (lookup) SpeechToText.androidIntentLookup,
          ],
        );
      } on MissingPluginException {
        return 'Voice was added after this app was installed. Stop the app and run it again';
      } on PlatformException catch (caught) {
        if (caught.code == 'recognizerNotAvailable' && !lookup) continue;
        if (caught.code == 'recognizerNotAvailable') {
          return 'This phone has no speech service. Install or update the Google app, then try again';
        }
        return 'Voice could not start (${caught.code})';
      }
      if (_speechReady) return null;
      if (!await _speech.hasPermission) {
        return 'Allow the microphone: Settings › Apps › zyvault › Permissions › Microphone';
      }
    }
    return 'Voice could not start on this phone';
  }

  void _onSpeech(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords;
    _text.value = TextEditingValue(
      text: words,
      selection: TextSelection.collapsed(offset: words.length),
    );
    if (!result.finalResult) return;
    setState(() => _listening = false);
    if (words.trim().isNotEmpty) _submit(words);
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      setState(() => _listening = false);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    const missed = {'error_no_match', 'error_speech_timeout'};
    setState(() {
      _listening = false;
      _error = missed.contains(error.errorMsg)
          ? "Didn't catch that, tap the mic and try again"
          : error.errorMsg.contains('permission')
          ? 'Allow the microphone: Settings › Apps › zyvault › Permissions › Microphone'
          : error.errorMsg == 'error_network' ||
                error.errorMsg == 'error_network_timeout'
          ? 'Voice needs internet for this language, check your connection'
          : error.errorMsg == 'error_language_not_supported' ||
                error.errorMsg == 'error_language_unavailable'
          ? 'This voice language is not installed. Add it in Google voice typing settings'
          : 'Voice stopped (${error.errorMsg}), try again';
    });
  }

  Future<void> _submit(String value) async {
    if (_saving || _message != null) return;
    final text = value.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Type an amount, a space, then what it was for');
      return;
    }
    if (looksLikeQuestion(text)) {
      await _ask(text);
      return;
    }
    final account = _account();
    if (account == null) {
      setState(() => _error = 'Add an account first');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final quick = isQuickSpend(
        text,
        categoryNames: widget.ledger.categories.map(
          (category) => category.name,
        ),
      );
      final message = quick
          ? await _saveLocally(text, account)
          : _review
          ? await _reviewThenSave(text, account)
          : await _saveWithAgent(text, account) ??
                (_needsAiOnly(text)
                    ? _needsAi(text)
                    : await _saveLocally(text, account));
      if (message == null || message.isEmpty || !mounted) return;
      FocusScope.of(context).unfocus();
      setState(() => _message = message);
      Celebration.play();
      await _fill.forward();
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = '$caught');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _ask(String question) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final answer = await widget.ledger.api.ask(
        question: question,
        today: isoDate(DateTime.now()),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      HapticFeedback.lightImpact();
      await showAskAnswer(context, question: question, answer: answer);
      if (mounted) _text.clear();
    } on FinanceException catch (caught) {
      if (!mounted) return;
      setState(
        () => _error = caught.unavailable
            ? 'Questions need the AI. Try again in a moment'
            : caught.message,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _needsAiOnly(String text) =>
      looksScheduled(text) ||
      looksLikeLoan(text) ||
      mentionsGoal(text, widget.ledger.goals);

  /// Returns the success message, null on an error, or '' when cancelled.
  Future<String?> _reviewThenSave(String text, Account account) async {
    List<ParsedSpend> drafts;
    try {
      drafts = await widget.ledger.previewText(
        text: text,
        accountId: account.id,
      );
    } on FinanceException catch (caught) {
      if (!caught.unavailable) rethrow;
      if (_needsAiOnly(text)) return _needsAi(text);
      drafts = _localDrafts(text, account);
    }
    if (!mounted) return null;
    if (drafts.isEmpty) {
      setState(() => _error = 'Type an amount, a space, then what it was for');
      return null;
    }
    setState(() => _saving = false);
    final picked = await reviewSpends(
      context,
      ledger: widget.ledger,
      sentence: text,
      drafts: drafts,
      defaultAccountId: account.id,
    );
    if (picked == null || picked.isEmpty || !mounted) return '';
    setState(() => _saving = true);
    final saved = await widget.ledger.commitSpends(
      items: picked,
      accountId: account.id,
    );
    return _messagesFor(saved);
  }

  List<ParsedSpend> _localDrafts(String text, Account chosen) {
    final mention = accountInText(
      text,
      widget.ledger.accounts,
      widget.ledger.bankFor,
    );
    final account = mention.account ?? chosen;
    final categories = widget.ledger.categories;
    return [
      for (final spend in parseSpendLines(mention.text))
        if (categoryFor(spend, categories) case final category?)
          ParsedSpend(
            amount: spend.amount,
            kind: spend.kind,
            occurredOn: isoDate(spend.occurredOn ?? DateTime.now()),
            categoryId: category.id,
            categoryName: category.name,
            note: spend.reason,
            accountId: account.id,
            accountName: account.name,
          ),
    ];
  }

  Future<String?> _saveWithAgent(String text, Account account) async {
    try {
      final saved = await widget.ledger.parseAndSave(
        text: text,
        accountId: account.id,
      );
      return _messagesFor(saved);
    } on FinanceException catch (caught) {
      if (caught.unavailable) return null;
      rethrow;
    }
  }

  String? _messagesFor(List<AgentResult> saved) {
    if (saved.isEmpty) return null;
    final warnings = budgetWarnings(widget.ledger, [
      for (final result in saved)
        if (result.transaction case final item? when item.kind == 'expense')
          item.categoryName,
    ]);
    return [
      for (final result in saved)
        if (result.schedule case final schedule?)
          scheduleMessage(
            schedule,
            accountName: _accountLabel(schedule.accountName),
          )
        else if (result.goal case final goal?)
          goalMessage(goal, result.goalEntry)
        else if (result.debt case final debt?)
          debtMessage(debt, accountName: _accountLabel(debt.accountName))
        else if (result.transaction case final item?)
          spendMessage(
            SpendLine(
              amount: item.amount,
              reason: item.note ?? item.categoryName,
              categoryName: item.categoryName,
              kind: item.kind,
              occurredOn: DateTime.tryParse(item.occurredOn),
              accountName: _accountLabel(item.accountName),
            ),
          ),
      ...warnings,
    ].join('\n');
  }

  String? _needsAi(String text) {
    setState(
      () => _error = mentionsGoal(text, widget.ledger.goals)
          ? 'Saving to a goal needs the AI. Try again in a moment, or tap the goal on Home'
          : looksLikeLoan(text)
          ? 'Lending and borrowing needs the AI. Try again in a moment, or add it in Money → People'
          : 'Planning future or monthly money needs the AI. Try again in a moment',
    );
    return null;
  }

  Future<String?> _saveLocally(String text, Account chosen) async {
    final mention = accountInText(
      text,
      widget.ledger.accounts,
      widget.ledger.bankFor,
    );
    final account = mention.account ?? chosen;
    final spends = parseSpendLines(mention.text);
    if (spends.isEmpty) {
      setState(() => _error = 'Type an amount, a space, then what it was for');
      return null;
    }
    final categories = widget.ledger.categories;
    if (spends.any((spend) => categoryFor(spend, categories) == null)) {
      setState(() => _error = 'Categories are not set up yet');
      return null;
    }
    for (final spend in spends) {
      await widget.ledger.saveTransaction(
        accountId: account.id,
        categoryId: categoryFor(spend, categories)!.id,
        amount: spend.amount,
        kind: spend.kind,
        occurredOn: isoDate(spend.occurredOn ?? DateTime.now()),
        note: spend.reason,
      );
    }
    final where = _accountLabel(account.name);
    final warnings = budgetWarnings(widget.ledger, [
      for (final spend in spends)
        if (spend.kind == 'expense') categoryFor(spend, categories)!.name,
    ]);
    final message = spendMessages([
      for (final spend in spends)
        SpendLine(
          amount: spend.amount,
          reason: spend.reason,
          categoryName: spend.categoryName,
          kind: spend.kind,
          occurredOn: spend.occurredOn,
          accountName: where,
        ),
    ]);
    return [message, ...warnings].join('\n');
  }

  Future<void> _scan() async {
    if (_saving || _message != null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Choose a photo'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose a PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'pdf') {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _readBill(bytes, 'application/pdf', keepPreview: false);
      return;
    }
    final shot = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 72,
    );
    if (shot == null || !mounted) return;
    final bytes = await shot.readAsBytes();
    if (!mounted) return;
    await _readBill(bytes, _billMime(shot), keepPreview: true);
  }

  Future<void> _readBill(
    Uint8List bytes,
    String mimeType, {
    required bool keepPreview,
  }) async {
    if (bytes.length > 4_500_000) {
      setState(
        () => _error =
            'That file is too large. Try a closer photo or a shorter PDF',
      );
      return;
    }
    final account = _account();
    if (account == null) {
      setState(() => _error = 'Add an account first');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final drafts = await widget.ledger.previewBill(
        imageBase64: base64Encode(bytes),
        mimeType: mimeType,
        accountId: account.id,
        text: _text.text.trim(),
      );
      if (!mounted) return;
      if (drafts.isEmpty) {
        setState(() => _error = 'No payable amount found on that bill');
        return;
      }
      setState(() {
        _billBytes = keepPreview ? bytes : null;
        _drafts = drafts;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = '$caught');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveBill(List<ParsedSpend> drafts) async {
    final account = _account();
    if (account == null) {
      setState(() => _error = 'Add an account first');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      for (final draft in drafts) {
        await widget.ledger.saveTransaction(
          accountId: account.id,
          categoryId: draft.categoryId,
          amount: draft.amount,
          kind: draft.kind,
          occurredOn: draft.occurredOn,
          note: draft.note,
        );
      }
      if (!mounted) return;
      setState(() {
        _drafts = null;
        _billBytes = null;
        _message = spendMessages([
          for (final draft in drafts)
            SpendLine(
              amount: draft.amount,
              reason: draft.note,
              categoryName: draft.categoryName,
              kind: draft.kind,
              occurredOn: DateTime.tryParse(draft.occurredOn),
            ),
        ]);
      });
      Celebration.play();
      await _fill.forward();
    } catch (caught) {
      if (!mounted) return;
      setState(() => _error = '$caught');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _billMime(XFile file) {
    const allowed = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    };
    final mime = file.mimeType?.toLowerCase();
    if (mime != null && allowed.contains(mime)) return mime;
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    if (path.endsWith('.heic')) return 'image/heic';
    if (path.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  Account? _account() {
    final accounts = widget.ledger.accounts;
    for (final account in accounts) {
      if (account.id == _accountId) return account;
    }
    for (final account in accounts) {
      if (account.type == 'cash') return account;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  String? _accountLabel(String? name) =>
      widget.ledger.accounts.length > 1 ? name : null;

  @override
  Widget build(BuildContext context) {
    final showing = _message != null;
    final drafts = _drafts;
    if (drafts != null && !showing) {
      return BillReview(
        imageBytes: _billBytes,
        drafts: drafts,
        categories: widget.ledger.categories,
        saving: _saving,
        error: _error,
        onCancel: () => setState(() {
          _drafts = null;
          _billBytes = null;
          _error = null;
        }),
        onSave: _saveBill,
      );
    }
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -300) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: showing
                      ? const SizedBox.shrink()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 88,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _error == null
                                        ? const SizedBox.shrink()
                                        : Text(
                                            _error!,
                                            key: ValueKey(_error),
                                            textAlign: TextAlign.center,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFFFF6B6B),
                                              fontSize: 14,
                                              height: 1.35,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            ValueListenableBuilder(
                              valueListenable: _text,
                              builder: (context, value, _) => TextField(
                                controller: _text,
                                autofocus: true,
                                readOnly: _saving,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.done,
                                minLines: 1,
                                maxLines: 6,
                                onSubmitted: _submit,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: typeFontSize(value.text.length),
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                                cursorColor: Colors.white,
                                cursorWidth: 2.5,
                                decoration: InputDecoration(
                                  hintText: 'What did you spend?',
                                  hintMaxLines: 2,
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 40,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: _saving || _listening
                                      ? null
                                      : _scan,
                                  icon: const Icon(
                                    Icons.document_scanner_outlined,
                                  ),
                                  color: const Color(0xFF8E8E93),
                                  tooltip: 'Read a bill',
                                ),
                                const SizedBox(width: 20),
                                _MicButton(
                                  listening: _listening,
                                  level: _level,
                                  onPressed: _saving ? null : _toggleVoice,
                                ),
                                const SizedBox(width: 20),
                                _LanguageChip(
                                  malayalam: _voiceLanguage == 'ml',
                                  onPressed: _listening || _saving
                                      ? null
                                      : _switchVoiceLanguage,
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 64,
                              child: ValueListenableBuilder(
                                valueListenable: _text,
                                builder: (context, value, _) {
                                  final Widget child;
                                  if (_saving) {
                                    child = const ThinkingOrb(
                                      key: ValueKey('orb'),
                                    );
                                  } else if (_listening) {
                                    child = Text(
                                      _voiceLanguage == 'ml'
                                          ? 'കേൾക്കുന്നു… stop talking or tap the mic when done'
                                          : 'Listening… stop talking or tap the mic when done',
                                      key: const ValueKey('listening'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFC8F57A),
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    );
                                  } else if (value.text.isEmpty &&
                                      _error == null) {
                                    child = Text(
                                      _voiceLanguage == 'ml'
                                          ? 'Try “ഇന്നലെ ബിരിയാണിക്ക് 340 രൂപ”\nor “450 pizza with friends”'
                                          : 'Try “450 pizza with friends”\nor “got 35k salary on 6th”',
                                      key: ValueKey('examples-$_voiceLanguage'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF6C6C70),
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    );
                                  } else {
                                    child = const SizedBox.shrink();
                                  }
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: child,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            if (!showing)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ListenableBuilder(
                      listenable: widget.ledger,
                      builder: (context, _) {
                        final account = _account();
                        if (account == null) return const SizedBox.shrink();
                        return AccountChip(
                          account: account,
                          bank: widget.ledger.bankFor(account),
                          onTap: _saving ? null : _chooseAccount,
                        );
                      },
                    ),
                  ),
                ),
              ),
            if (!showing)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PayChip(
                      name: _payee,
                      onTap: _saving ? null : _paySomeone,
                    ),
                  ),
                ),
              ),
            if (showing)
              AnimatedBuilder(
                animation: _fill,
                builder: (context, _) {
                  return _SuccessFill(
                    progress: _fill.value,
                    message: _message!,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PayChip extends StatelessWidget {
  const _PayChip({required this.name, required this.onTap});

  final String? name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = name ?? 'Pay someone';
    return Semantics(
      button: true,
      label: name == null
          ? 'Pay someone, tap to choose a contact'
          : 'Paying $name, tap to choose another contact',
      child: Material(
        color: const Color(0xFF1C1C1E),
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFF3A3A3C))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PayAvatar(name: name),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.chevronDown,
                    color: Color(0xFF8E8E93),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayAvatar extends StatelessWidget {
  const _PayAvatar({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name?.trim() ?? '';
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2E),
        shape: BoxShape.circle,
      ),
      child: trimmed.isEmpty
          ? const Icon(LucideIcons.userRound, color: Colors.white, size: 16)
          : Text(
              trimmed[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFC8F57A),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.malayalam, required this.onPressed});

  final bool malayalam;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: malayalam
          ? 'Voice language Malayalam, tap for English'
          : 'Voice language English, tap for Malayalam',
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: const Color(0xFF2C2C2E),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  malayalam ? 'മ' : 'EN',
                  style: TextStyle(
                    color: onPressed == null
                        ? const Color(0xFF5C5C60)
                        : malayalam
                        ? const Color(0xFFC8F57A)
                        : Colors.white,
                    fontSize: malayalam ? 18 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.level,
    required this.onPressed,
  });

  final bool listening;
  final double level;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const lime = Color(0xFFC8F57A);
    return Semantics(
      button: true,
      label: listening ? 'Stop listening' : 'Speak a spend',
      child: SizedBox.square(
        dimension: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: listening ? 56 + 16 * level : 56,
              height: listening ? 56 + 16 * level : 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: listening
                    ? lime.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            Material(
              color: listening ? lime : const Color(0xFF2C2C2E),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: 52,
                  child: Icon(
                    listening ? LucideIcons.square : LucideIcons.mic,
                    color: listening
                        ? const Color(0xFF17310C)
                        : onPressed == null
                        ? const Color(0xFF5C5C60)
                        : Colors.white,
                    size: listening ? 20 : 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessFill extends StatelessWidget {
  const _SuccessFill({required this.progress, required this.message});

  final double progress;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = ((progress - 0.42) / 0.35).clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _BlobPainter(progress)),
        Opacity(
          opacity: text,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Transform.scale(
                scale: 0.9 + 0.1 * text,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF17310C),
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.progress);

  final double progress;

  static const _blobs = <(double, double, double, Color)>[
    (0.48, 0.5, 0.2, Color(0xFFC8F57A)),
    (0.18, 0.24, 1.4, Color(0xFFB6F26A)),
    (0.82, 0.7, 2.2, Color(0xFF9BE15D)),
    (0.72, 0.2, 0.8, Color(0xFFD4FF8A)),
    (0.28, 0.78, 2.8, Color(0xFF8ED64A)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final grow = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    for (final blob in _blobs) {
      final center = Offset(size.width * blob.$1, size.height * blob.$2);
      final radius = size.longestSide * (0.08 + 1.25 * grow);
      canvas.drawPath(
        _organic(center, radius, blob.$3 + progress * 1.6),
        Paint()..color = blob.$4,
      );
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFFC8F57A)
            .withValues(alpha: ((progress - 0.38) / 0.4).clamp(0, 1)),
    );
  }

  Path _organic(Offset center, double radius, double phase) {
    const steps = 7;
    final points = <Offset>[];
    for (var index = 0; index < steps; index++) {
      final angle = index / steps * math.pi * 2;
      final wobble = 1 + 0.22 * math.sin(angle * 3 + phase);
      points.add(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * wobble,
      );
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

Future<void> openTypePage(
  BuildContext context,
  Ledger ledger, {
  bool startVoice = false,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          TypePage(ledger: ledger, startVoice: startVoice),
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final position =
            Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: position, child: child);
      },
    ),
  );
}
