import 'package:finance_track/money.dart';

class HistoryPeriod {
  const HistoryPeriod({
    required this.start,
    required this.end,
    required this.previousLabel,
    required this.label,
    required this.nextLabel,
  });

  final DateTime start;
  final DateTime end;
  final String previousLabel;
  final String label;
  final String nextLabel;
}

HistoryPeriod historyPeriod(String span, DateTime anchor, {DateTime? now}) {
  final today = now ?? DateTime.now();
  switch (span) {
    case 'week':
      return _week(anchor, today);
    case 'quarter':
      return _quarter(anchor, today);
    default:
      return _month(anchor, today);
  }
}

DateTime shiftAnchor(String span, DateTime anchor, int delta) {
  switch (span) {
    case 'week':
      return anchor.add(Duration(days: 7 * delta));
    case 'quarter':
      return DateTime(anchor.year, anchor.month + 3 * delta, 1);
    default:
      return DateTime(anchor.year, anchor.month + delta, 1);
  }
}

HistoryPeriod _month(DateTime anchor, DateTime today) {
  final start = DateTime(anchor.year, anchor.month);
  return HistoryPeriod(
    start: start,
    end: DateTime(anchor.year, anchor.month + 1),
    previousLabel: _monthName(DateTime(anchor.year, anchor.month - 1), today),
    label: _monthName(start, today),
    nextLabel: _monthName(DateTime(anchor.year, anchor.month + 1), today),
  );
}

HistoryPeriod _week(DateTime anchor, DateTime today) {
  final start = DateTime(
    anchor.year,
    anchor.month,
    anchor.day,
  ).subtract(Duration(days: anchor.weekday - 1));
  return HistoryPeriod(
    start: start,
    end: start.add(const Duration(days: 7)),
    previousLabel: _dayLabel(start.subtract(const Duration(days: 7)), today),
    label: _dayLabel(start, today),
    nextLabel: _dayLabel(start.add(const Duration(days: 7)), today),
  );
}

HistoryPeriod _quarter(DateTime anchor, DateTime today) {
  final quarterStartMonth = ((anchor.month - 1) ~/ 3) * 3 + 1;
  final start = DateTime(anchor.year, quarterStartMonth);
  return HistoryPeriod(
    start: start,
    end: DateTime(anchor.year, quarterStartMonth + 3),
    previousLabel: _quarterName(
      DateTime(anchor.year, quarterStartMonth - 3),
      today,
    ),
    label: _quarterName(start, today),
    nextLabel: _quarterName(
      DateTime(anchor.year, quarterStartMonth + 3),
      today,
    ),
  );
}

String _monthName(DateTime date, DateTime today) {
  const names = [
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
  final name = names[date.month - 1];
  return date.year == today.year ? name : '$name ${date.year}';
}

String _dayLabel(DateTime date, DateTime today) {
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
  final text = '${date.day} ${months[date.month - 1]}';
  return date.year == today.year ? text : '$text ${date.year}';
}

String _quarterName(DateTime date, DateTime today) {
  final quarter = ((date.month - 1) ~/ 3) + 1;
  return date.year == today.year ? 'Q$quarter' : 'Q$quarter ${date.year}';
}

String periodQueryStart(HistoryPeriod period) => isoDate(period.start);

String periodQueryEnd(HistoryPeriod period) => isoDate(period.end);
