import 'package:finance_track/money.dart';

class BankSms {
  const BankSms({
    required this.id,
    required this.sender,
    required this.body,
    required this.date,
    required this.amount,
    required this.kind,
    this.bankId,
    this.accountDigits,
    this.merchant,
    this.app,
    this.alsoIds = const [],
  });

  final String id;
  final String sender;
  final String body;
  final DateTime date;
  final int amount;
  final String kind;
  final String? bankId;
  final String? accountDigits;
  final String? merchant;
  final String? app;
  final List<String> alsoIds;

  bool get fromApp => app != null;

  List<String> get ids => [id, ...alsoIds];

  BankSms mergedWith(BankSms other) => BankSms(
    id: id,
    sender: sender,
    body: body,
    date: date,
    amount: amount,
    kind: kind,
    bankId: bankId,
    accountDigits: accountDigits,
    merchant: merchant ?? other.merchant,
    app: app,
    alsoIds: [...alsoIds, ...other.ids],
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'sender': sender,
    'body': body,
    'date': date.millisecondsSinceEpoch,
    'amount': amount,
    'kind': kind,
    'merchant': merchant,
    'app': app,
  };

  factory BankSms.fromJson(Map<String, dynamic> json) => BankSms(
    id: json['id'] as String,
    sender: json['sender'] as String,
    body: json['body'] as String,
    date: DateTime.fromMillisecondsSinceEpoch((json['date'] as num).toInt()),
    amount: (json['amount'] as num).toInt(),
    kind: json['kind'] as String,
    merchant: json['merchant'] as String?,
    app: json['app'] as String?,
  );
}

const upiApps = <String, String>{
  'com.google.android.apps.nbu.paisa.user': 'GPay',
  'com.phonepe.app': 'PhonePe',
  'net.one97.paytm': 'Paytm',
  'in.org.npci.upiapp': 'BHIM',
  'com.dreamplug.androidapp': 'CRED',
};

final _appIgnore = RegExp(
  r'\b(request|requested|requesting|collect|reminder|remind|cashback|reward|'
  r'scratch|offer|won|win|failed|failure|pending|declined|processing|'
  r'bill due|due on|pay now|expires|expiring|get up to|upto|kyc|loan)\b',
);

final _appPatterns = <(RegExp, String)>[
  (
    RegExp(
      r'^(.+?) (?:has )?paid you (?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    ),
    'income',
  ),
  (
    RegExp(
      r'(?:received|got) (?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?) from (.+?)(?:[.!]|$| on | via )',
    ),
    'income',
  ),
  (
    RegExp(
      r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?) received from (.+?)(?:[.!]|$| on | via )',
    ),
    'income',
  ),
  (
    RegExp(
      r'(?:you )?(?:received|got) (?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    ),
    'income',
  ),
  (
    RegExp(
      r'(?:paid|sent) (?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?) to (.+?)(?:[.!]|$| on | via | using )',
    ),
    'expense',
  ),
  (
    RegExp(
      r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?) (?:paid|sent)[.!]?\s+to (.+?)(?:[.!]|$| on | via | using )',
    ),
    'expense',
  ),
  (
    RegExp(
      r'(?:you )?paid (.+?)[.!]?\s*(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    ),
    'expense',
  ),
  (
    RegExp(
      r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?) (?:paid|sent) to (.+?)(?:[.!]|$| on | via | using )',
    ),
    'expense',
  ),
  (
    RegExp(
      r'payment of (?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?) to (.+?) (?:was |is )?successful',
    ),
    'expense',
  ),
];

BankSms? parseUpiNotification({
  required String packageName,
  required String title,
  required String content,
  required DateTime date,
}) {
  final app = upiApps[packageName];
  if (app == null) return null;
  final text = '$title. $content'
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (_appIgnore.hasMatch(text)) return null;
  for (final (pattern, kind) in _appPatterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final personFirst =
        pattern.pattern.startsWith('^(.+?) (?:has )?paid you') ||
        pattern.pattern.startsWith('(?:you )?paid (');
    final amountText = personFirst ? match.group(2)! : match.group(1)!;
    final person = personFirst
        ? match.group(1)
        : match.groupCount >= 2
        ? match.group(2)
        : null;
    final amount = parseMoney(amountText.replaceAll(',', ''));
    if (amount == null) return null;
    final name = person == null ? null : _cleanMerchant(person);
    return BankSms(
      id: 'APP|$packageName|${date.millisecondsSinceEpoch}|${text.hashCode}',
      sender: name == null ? app : '$app $name',
      body: [title, content].where((part) => part.trim().isNotEmpty).join('\n'),
      date: date,
      amount: amount,
      kind: kind,
      merchant: name,
      app: app,
    );
  }
  return null;
}

bool sameMoney(BankSms a, BankSms b) {
  return a.amount == b.amount &&
      a.kind == b.kind &&
      a.date.difference(b.date).abs() <= const Duration(minutes: 15);
}

List<BankSms> mergeAlerts(List<BankSms> sms, List<BankSms> apps) {
  final merged = [...sms];
  for (final alert in apps) {
    final index = merged.indexWhere((item) => sameMoney(item, alert));
    if (index < 0) {
      merged.add(alert);
    } else {
      merged[index] = merged[index].mergedWith(alert);
    }
  }
  merged.sort((a, b) => a.date.compareTo(b.date));
  return merged;
}

const _senderBanks = <String, String>{
  'HDFCBK': 'hdfc',
  'HDFCBN': 'hdfc',
  'SBIINB': 'sbi',
  'SBIUPI': 'sbi',
  'SBMSMS': 'sbi',
  'CBSSBI': 'sbi',
  'ATMSBI': 'sbi',
  'SBICRD': 'sbi',
  'ICICIB': 'icici',
  'ICICIT': 'icici',
  'AXISBK': 'axis',
  'AXISMR': 'axis',
  'KOTAKB': 'kotak',
  'KOTAK': 'kotak',
  'PNBSMS': 'pnb',
  'PUNBNK': 'pnb',
  'BOBTXN': 'bob',
  'BOBSMS': 'bob',
  'BARODA': 'bob',
  'CANBNK': 'canara',
  'UNIONB': 'union',
  'UBOI': 'union',
  'BOIIND': 'boi',
  'INDBNK': 'indian',
  'IOBCHN': 'iob',
  'IOBBNK': 'iob',
  'CENTBK': 'central',
  'UCOBNK': 'uco',
  'INDUSB': 'indusind',
  'YESBNK': 'yes',
  'IDFCFB': 'idfc',
  'FEDBNK': 'federal',
  'SIBSMS': 'sib',
  'SIBANK': 'sib',
  'CSBBNK': 'csb',
  'DHANBK': 'dhanlaxmi',
  'KGBANK': 'kgb',
  'AUBANK': 'au',
  'IPBMSG': 'ippb',
  'PAYTMB': 'paytm',
  'AIRBNK': 'airtel',
};

const _bodyBanks = <String, String>{
  'hdfc bank': 'hdfc',
  'state bank': 'sbi',
  'sbi': 'sbi',
  'icici': 'icici',
  'axis bank': 'axis',
  'kotak': 'kotak',
  'punjab national': 'pnb',
  'pnb': 'pnb',
  'bank of baroda': 'bob',
  'canara': 'canara',
  'union bank': 'union',
  'bank of india': 'boi',
  'indian bank': 'indian',
  'indian overseas': 'iob',
  'central bank': 'central',
  'uco bank': 'uco',
  'indusind': 'indusind',
  'yes bank': 'yes',
  'idfc': 'idfc',
  'federal bank': 'federal',
  'south indian bank': 'sib',
  'csb bank': 'csb',
  'dhanlaxmi': 'dhanlaxmi',
  'kerala gramin': 'kgb',
  'au small finance': 'au',
  'au bank': 'au',
  'india post payments': 'ippb',
  'paytm payments': 'paytm',
  'airtel payments': 'airtel',
};

final _ignore = RegExp(
  r'\b(otp|one time password|verification code|passcode|will be debited|'
  r'to be debited|is due|due on|due date|minimum due|min\.? amt due|'
  r'requested|request of|collect request|declined|failed|unsuccessful|'
  r'not processed|reversal|offer|cashback of upto|upto|up to rs|win |'
  r'congratulations|pre-approved|pre approved|loan of|eligible for|'
  r'statement|bill generated|e-mandate|autopay set|mandate)\b',
);

final _debit = RegExp(
  r'\b(debited|debit|spent|paid|sent|withdrawn|withdrawal|purchase|'
  r'purchased|dr\.?|txn of|transferred|deducted)\b',
);

final _credit = RegExp(
  r'\b(credited|credit of|received|deposited|cr\.?|refund|refunded)\b',
);

final _amount = RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)');

final _verbAmount = RegExp(
  r'\b(?:debited|credited|sent|paid|spent|withdrawn|deducted|received)\s+'
  r'(?:by|for|with|of)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
);

final _balance = RegExp(
  r'\b(avl\.?\s*bal|available bal|avbl bal|bal\s*[:.]|balance)',
);

final _digits = RegExp(
  r'(?:a/c|a/c no\.?|ac|acct|account|card)\s*(?:no\.?|number)?\s*'
  r'(?:ending|ending with|ending in)?\s*[x*]*\s*(\d{3,6})',
);

final _merchant = RegExp(
  r'\b(?:at|to|towards|vpa|info:?|by|from)\s+'
  r"([a-z][a-z0-9@._&'\- ]{1,39}?)"
  r'(?=\s+(?:on|ref|refno|via|upi|avl|a/c|dt|date|using|for|txn|thru|from|by|to|at)\b|[.,;(]|$)',
);

final _personalNumber = RegExp(r'^\+?\d{6,}$');

String _senderCode(String sender) {
  final parts = sender.toUpperCase().trim().split('-')
    ..sort((a, b) => b.length.compareTo(a.length));
  return parts.first.replaceAll(RegExp(r'[^A-Z]'), '');
}

const _exactBanks = <String, String>{
  'SBI': 'sbi',
  'HDFC': 'hdfc',
  'ICICI': 'icici',
  'AXIS': 'axis',
};

String? bankFromSender(String sender) {
  final code = _senderCode(sender);
  if (_exactBanks.containsKey(code)) return _exactBanks[code];
  if (_senderBanks.containsKey(code)) return _senderBanks[code];
  for (final entry in _senderBanks.entries) {
    if (code.contains(entry.key)) return entry.value;
  }
  return null;
}

const _smsApps = <String>{
  'com.google.android.apps.messaging',
  'com.android.mms',
  'com.android.messaging',
  'com.samsung.android.messaging',
  'com.truecaller',
};

bool _mentionsBank(String text) {
  final lower = text.toLowerCase();
  return _bodyBanks.keys.any(lower.contains);
}

/// A bank SMS or UPI alert, read from a notification without requiring every
/// platform flag to be present.
BankSms? paymentFromNotification({
  required String packageName,
  required String title,
  required String content,
  required DateTime date,
  bool removed = false,
  bool ongoing = false,
}) {
  if (removed || ongoing) return null;
  return parseUpiNotification(
        packageName: packageName,
        title: title,
        content: content,
        date: date,
      ) ??
      parseSmsNotification(
        packageName: packageName,
        title: title,
        content: content,
        date: date,
      );
}

BankSms? parseSmsNotification({
  required String packageName,
  required String title,
  required String content,
  required DateTime date,
}) {
  final sender = title.trim();
  final body = content.trim();
  if (sender.isEmpty && body.isEmpty) return null;
  final text = body.isEmpty ? sender : body;
  final from = sender.isEmpty ? 'Bank' : sender;
  final known =
      _smsApps.contains(packageName) ||
      bankFromSender(from) != null ||
      _mentionsBank('$from $text');
  if (!known) return null;
  return parseBankSms(
    id: smsKey(from, text, date),
    sender: from,
    body: text,
    date: date,
  );
}

String senderKey(String sender) {
  final parts = sender.toUpperCase().trim().split('-')
    ..sort((a, b) => b.length.compareTo(a.length));
  return parts.first;
}

String smsKey(String sender, String body, DateTime date) {
  return '${senderKey(sender)}|${date.millisecondsSinceEpoch}|${body.hashCode}';
}

BankSms? parseBankSms({
  required String id,
  required String sender,
  required String body,
  required DateTime date,
}) {
  if (_personalNumber.hasMatch(sender.trim())) return null;
  final text = body.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (_ignore.hasMatch(text)) return null;

  final debit = _debit.firstMatch(text);
  final credit = _credit.firstMatch(text);
  if (debit == null && credit == null) return null;
  final kind = credit == null || (debit != null && debit.start < credit.start)
      ? 'expense'
      : 'income';

  final balanceAt = _balance.firstMatch(text)?.start ?? text.length;
  final beforeBalance = text.substring(0, balanceAt);
  final money =
      _amount.firstMatch(beforeBalance) ??
      _verbAmount.firstMatch(beforeBalance);
  if (money == null) return null;
  final amount = parseMoney(money.group(1)!.replaceAll(',', ''));
  if (amount == null) return null;

  String? bankId = bankFromSender(sender);
  if (bankId == null) {
    for (final entry in _bodyBanks.entries) {
      if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(text)) {
        bankId = entry.value;
        break;
      }
    }
  }
  if (bankId == null &&
      !RegExp(r'\b(a/c|account|card|upi|bank)\b').hasMatch(text)) {
    return null;
  }

  return BankSms(
    id: id,
    sender: sender,
    body: body.trim(),
    date: date,
    amount: amount,
    kind: kind,
    bankId: bankId,
    accountDigits: _digits.firstMatch(text)?.group(1),
    merchant: _merchantIn(text),
  );
}

final _notMerchant = RegExp(
  r'^(a/c|ac|account|your|you|self|card|neft|imps|rtgs|upi|ach|nach|atm|cash|'
  r'transfer|bank|net banking|netbanking|mobile banking|debit card|credit card)\b',
);

String? _merchantIn(String text) {
  for (final match in _merchant.allMatches(text)) {
    final name = _cleanMerchant(match.group(1)!);
    if (name != null) return name;
  }
  return null;
}

String? _cleanMerchant(String raw) {
  var name = raw.trim();
  if (name.contains('@')) name = name.split('@').first;
  name = name
      .replaceAll(RegExp(r'^(vpa|upi|a/c|ac|your)\s+'), '')
      .replaceAll(RegExp(r'[._\-]+'), ' ')
      .replaceAll(RegExp(r'\d{6,}'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.length < 2 ||
      _notMerchant.hasMatch(name) ||
      RegExp(r'\bbank\b|^(rs|inr)\b').hasMatch(name)) {
    return null;
  }
  return name
      .split(' ')
      .map(
        (word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
      )
      .join(' ');
}
