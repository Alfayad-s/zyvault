import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/notifications.dart';
import 'package:finance_track/push.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _enabledKey = 'reminders_enabled';
const _reminderHour = 9;
const _monthsAhead = 3;

class Reminder {
  const Reminder({
    required this.at,
    required this.title,
    required this.body,
    this.exact = false,
  });

  final DateTime at;
  final String title;
  final String body;

  /// Set when the user named a time, so it should fire on the minute.
  final bool exact;
}

DateTime _monthly(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > last ? last : day);
}

List<DateTime> upcomingDates(Schedule schedule) {
  final first = DateTime.parse(schedule.nextOn);
  if (!schedule.monthly) return [first];
  return [
    for (var offset = 0; offset < _monthsAhead; offset++)
      _monthly(first.year, first.month + offset, schedule.dayOfMonth),
  ];
}

/// With [serverPush] the server sends untimed reminders, so only timed ones stay on the phone.
List<Reminder> remindersFor(
  Schedule schedule,
  DateTime now, {
  bool serverPush = false,
}) {
  if (serverPush && schedule.atTime == null) return const [];
  final what = schedule.note ?? schedule.categoryName;
  final amount = formatRupees(schedule.amount);
  final reminders = <Reminder>[];
  final clock = schedule.atTime?.split(':');
  if (clock != null && clock.length == 2) {
    final hour = int.tryParse(clock[0]) ?? _reminderHour;
    final minute = int.tryParse(clock[1]) ?? 0;
    final where = schedule.accountName == null
        ? ''
        : ' · ${schedule.accountName}';
    for (final day in upcomingDates(schedule)) {
      final at = DateTime(day.year, day.month, day.day, hour, minute);
      if (!at.isAfter(now)) continue;
      reminders.add(
        Reminder(
          at: at,
          title: schedule.kind == 'income'
              ? 'Money expected now: $amount'
              : 'Time to pay $amount',
          body: '$what$where',
          exact: true,
        ),
      );
    }
    return reminders;
  }
  for (final day in upcomingDates(schedule)) {
    final onDay = DateTime(day.year, day.month, day.day, _reminderHour);
    if (schedule.kind == 'income') {
      if (onDay.isAfter(now)) {
        reminders.add(
          Reminder(at: onDay, title: 'Expected today: $amount', body: what),
        );
      }
      continue;
    }
    final before = onDay.subtract(const Duration(days: 1));
    if (before.isAfter(now)) {
      reminders.add(
        Reminder(at: before, title: 'Due tomorrow: $amount', body: what),
      );
    } else if (onDay.isAfter(now)) {
      reminders.add(
        Reminder(at: onDay, title: 'Due today: $amount', body: what),
      );
    }
  }
  return reminders;
}

class Reminders {
  Reminders._();

  static FlutterLocalNotificationsPlugin get _plugin => Notifier.plugin;
  static Future<void>? _ready;

  static Future<bool> enabled() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_enabledKey) ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool value, List<Schedule> schedules) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
    if (value) {
      await sync(schedules, askPermission: true);
    } else {
      await _init();
      await _cancelOwn();
    }
  }

  static Future<void> _cancelOwn() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= reminderIds.start && request.id < reminderIds.end) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  static Future<void> _init() {
    return _ready ??= () async {
      tz_data.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }
      await Notifier.init();
    }();
  }

  static Future<void> sync(
    List<Schedule> schedules, {
    bool askPermission = false,
  }) async {
    try {
      if (!await enabled()) return;
      await _init();
      await _cancelOwn();
      final now = DateTime.now();
      final serverPush = await Push.serverHandlesReminders();
      final reminders = [
        for (final schedule in schedules)
          ...remindersFor(schedule, now, serverPush: serverPush),
      ];
      if (reminders.isEmpty) return;
      if (askPermission || !await _askedBefore()) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true);
        await _markAsked();
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      var exactAllowed = false;
      if (android != null && reminders.any((reminder) => reminder.exact)) {
        exactAllowed = await android.canScheduleExactNotifications() ?? false;
        if (!exactAllowed && !await _askedExactBefore()) {
          await _markAskedExact();
          await android.requestExactAlarmsPermission();
          exactAllowed = await android.canScheduleExactNotifications() ?? false;
        }
      }
      for (final (index, reminder) in reminders.indexed) {
        await _plugin.zonedSchedule(
          id: reminderIds.start + index,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
          androidScheduleMode: reminder.exact && exactAllowed
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'bills',
              'Bills and salary',
              channelDescription: 'Reminders for scheduled bills and income',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    } catch (caught) {
      debugPrint('Could not schedule reminders: $caught');
    }
  }

  static Future<bool> _askedExactBefore() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('exact_alarms_asked') ?? false;
  }

  static Future<void> _markAskedExact() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('exact_alarms_asked', true);
  }

  static Future<bool> _askedBefore() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('reminders_asked') ?? false;
  }

  static Future<void> _markAsked() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('reminders_asked', true);
  }
}
