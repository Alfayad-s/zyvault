String formatMoney(int minor) {
  final negative = minor < 0;
  final absolute = minor.abs();
  final major = absolute ~/ 100;
  final cents = (absolute % 100).toString().padLeft(2, '0');
  final digits = major.toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      grouped.write(',');
    }
    grouped.write(digits[index]);
  }
  final text = '$grouped.$cents';
  return negative ? '-$text' : text;
}

int? parseMoney(String text) {
  final cleaned = text.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) {
    return null;
  }
  final parts = cleaned.split('.');
  final major = int.parse(parts[0]);
  final minor = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  final amount = major * 100 + minor;
  return amount == 0 ? null : amount;
}

int? parseOpeningBalance(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) {
    return 0;
  }
  final negative = cleaned.startsWith('-');
  final amount = parseMoney(negative ? cleaned.substring(1) : cleaned);
  if (amount == null) {
    return cleaned == '0' || cleaned == '0.0' || cleaned == '0.00' ? 0 : null;
  }
  return negative ? -amount : amount;
}

String formatCompact(int minor) {
  if (minor == 0) return '₹0';
  final negative = minor < 0;
  final absolute = minor.abs();
  final major = absolute / 100;
  final String body;
  if (major >= 10000000) {
    body = '${_oneDecimal(major / 10000000)}Cr';
  } else if (major >= 100000) {
    body = '${_oneDecimal(major / 100000)}L';
  } else if (major >= 1000) {
    body = '${_oneDecimal(major / 1000)}K';
  } else if (absolute % 100 == 0) {
    body = major.toInt().toString();
  } else {
    body = formatMoney(absolute);
  }
  return negative ? '-₹$body' : '₹$body';
}

/// Note saved when money is sent to, or received from, a chosen contact.
String personPaymentNote({
  required String name,
  required int amount,
  required String kind,
  String? detail,
}) {
  final money = formatRupees(amount);
  final sent = kind == 'income'
      ? 'received $money from $name'
      : 'sent $name $money';
  final extra = paymentDetail(detail, name);
  return extra == null ? sent : '$sent, $extra';
}

/// Drops a detail that only repeats the person or the words "I spent".
String? paymentDetail(String? detail, String name) {
  if (detail == null) return null;
  var text = detail.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return null;
  final person = RegExp.escape(name.trim());
  text = text
      .replaceFirst(
        RegExp('^sent\\s+(to\\s+)?$person\\b[\\s,₹\\d.]*', caseSensitive: false),
        '',
      )
      .trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (lower == name.trim().toLowerCase()) return null;
  if (RegExp(
    r'^(i\s+)?(spent|spend|spending|paid|pay|sent|expense|kharcha)$',
    caseSensitive: false,
  ).hasMatch(lower)) {
    return null;
  }
  return text;
}

String formatRupees(int minor) {
  if (minor % 100 == 0) {
    return '₹${formatMoney(minor).split('.').first}';
  }
  return '₹${formatMoney(minor)}';
}

String _oneDecimal(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

String formatDate(String iso) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final parts = iso.split('-');
  if (parts.length != 3) {
    return iso;
  }
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null || month < 1 || month > 12) {
    return iso;
  }
  return '$day ${months[month - 1]} ${parts[0]}';
}

String monthKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month';
}

String monthLabel(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Local time as HH:MM in 24 hours.
String clockTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// "18:00" → "6:00 PM".
String formatClock(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final hour = int.tryParse(parts[0]);
  final minute = parts[1];
  if (hour == null) return hhmm;
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelve:$minute ${hour < 12 ? 'AM' : 'PM'}';
}
