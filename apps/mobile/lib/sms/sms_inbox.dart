import 'dart:convert';
import 'dart:io' show Platform;

import 'package:finance_track/sms/bank_sms.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _enabledKey = 'sms_enabled';
const _appsKey = 'upi_enabled';
const _sinceKey = 'sms_since';
const _seenKey = 'sms_seen';
const _spamKey = 'sms_spam_senders';
const _alertsKey = 'upi_alerts';
const _firstLookBack = Duration(days: 3);
const _maxSeen = 800;
const _maxPending = 20;
const _maxAlerts = 60;

class SmsInbox {
  SmsInbox._();

  static bool get supported => Platform.isAndroid;

  static Future<bool> enabled() async {
    if (!supported) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> appsEnabled() async {
    if (!supported) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!(preferences.getBool(_appsKey) ?? false)) return false;
      return await NotificationListenerService.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  static Future<String?> enable() async {
    if (!supported) return 'Reading bank SMS works only on Android';
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return 'Allow SMS for zyvault, then turn this on again';
      }
      return 'SMS permission is needed to read bank messages';
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_enabledKey, true);
      await _startWindow(preferences);
    } catch (_) {
      return 'Could not save the SMS setting. Try again';
    }
    return null;
  }

  static Future<String?> enableApps() async {
    if (!supported) return 'Reading UPI apps works only on Android';
    bool granted;
    try {
      granted =
          await NotificationListenerService.isPermissionGranted() ||
          await NotificationListenerService.requestPermission();
    } catch (_) {
      granted = false;
    }
    if (!granted) {
      return 'Turn on notification access for zyvault, then switch this on again';
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_appsKey, true);
      await _startWindow(preferences);
    } catch (_) {
      return 'Could not save the UPI setting. Try again';
    }
    return null;
  }

  static Future<void> _startWindow(SharedPreferences preferences) async {
    if (!preferences.containsKey(_sinceKey)) {
      await preferences.setInt(
        _sinceKey,
        DateTime.now().subtract(_firstLookBack).millisecondsSinceEpoch,
      );
    }
  }

  static Future<void> disable() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
  }

  static Future<void> disableApps() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_appsKey, false);
  }

  static Future<bool> storeAppAlert(BankSms alert) async {
    final preferences = await SharedPreferences.getInstance();
    final seen = (preferences.getStringList(_seenKey) ?? const []).toSet();
    if (seen.contains(alert.id)) return false;
    final stored = preferences.getStringList(_alertsKey) ?? <String>[];
    if (stored.any((item) => item.contains('"id":${jsonEncode(alert.id)}'))) {
      return false;
    }
    stored.add(jsonEncode(alert.toJson()));
    await preferences.setStringList(
      _alertsKey,
      stored.length > _maxAlerts
          ? stored.sublist(stored.length - _maxAlerts)
          : stored,
    );
    return true;
  }

  static Future<List<BankSms>> pending() async {
    final smsOn = await enabled();
    final appsOn = await appsEnabled();
    if (!smsOn && !appsOn) return [];
    final preferences = await SharedPreferences.getInstance();
    final since = DateTime.fromMillisecondsSinceEpoch(
      preferences.getInt(_sinceKey) ??
          DateTime.now().subtract(_firstLookBack).millisecondsSinceEpoch,
    );
    final seen = (preferences.getStringList(_seenKey) ?? const []).toSet();
    final spam = (preferences.getStringList(_spamKey) ?? const []).toSet();
    bool keep(BankSms item) =>
        !item.date.isBefore(since) &&
        !seen.contains(item.id) &&
        !spam.contains(senderKey(item.sender));

    final sms = smsOn ? await _smsAlerts() : <BankSms>[];
    final apps = appsOn ? await _appAlerts(preferences) : <BankSms>[];
    final found = mergeAlerts(
      sms.where(keep).toList(),
      apps.where(keep).toList(),
    );
    return found.length > _maxPending
        ? found.sublist(found.length - _maxPending)
        : found;
  }

  static Future<List<BankSms>> _smsAlerts() async {
    if (!await Permission.sms.isGranted) return [];
    List<SmsMessage> messages;
    try {
      messages = await SmsQuery().querySms(
        kinds: [SmsQueryKind.inbox],
        count: 300,
      );
    } catch (caught) {
      debugPrint('Could not read SMS: $caught');
      return [];
    }
    return [
      for (final message in messages)
        if (message.date case final date?)
          ?parseBankSms(
            id: smsKey(message.address ?? '', message.body ?? '', date),
            sender: message.address ?? '',
            body: message.body ?? '',
            date: date,
          ),
    ];
  }

  static Future<List<BankSms>> _appAlerts(SharedPreferences preferences) async {
    final alerts = <BankSms>[
      for (final item in preferences.getStringList(_alertsKey) ?? const [])
        BankSms.fromJson(jsonDecode(item) as Map<String, dynamic>),
    ];
    try {
      final active = await NotificationListenerService.getActiveNotifications();
      for (final event in active) {
        final parsed = alertFromNotification(event);
        if (parsed != null && !alerts.any((item) => item.id == parsed.id)) {
          alerts.add(parsed);
        }
      }
    } catch (caught) {
      debugPrint('Could not read notifications: $caught');
    }
    return alerts;
  }

  static Future<void> markSeen(BankSms sms) async {
    final preferences = await SharedPreferences.getInstance();
    final seen = preferences.getStringList(_seenKey) ?? <String>[];
    for (final id in sms.ids) {
      if (!seen.contains(id)) seen.add(id);
    }
    await preferences.setStringList(
      _seenKey,
      seen.length > _maxSeen ? seen.sublist(seen.length - _maxSeen) : seen,
    );
    final stored = preferences.getStringList(_alertsKey);
    if (stored != null) {
      final ids = sms.ids.toSet();
      stored.removeWhere(
        (item) => ids.contains(
          (jsonDecode(item) as Map<String, dynamic>)['id'] as String,
        ),
      );
      await preferences.setStringList(_alertsKey, stored);
    }
  }

  static Future<void> reportSpam(BankSms sms) async {
    final preferences = await SharedPreferences.getInstance();
    final spam = preferences.getStringList(_spamKey) ?? <String>[];
    final key = senderKey(sms.sender);
    if (!spam.contains(key)) spam.add(key);
    await _saveSpam(preferences, spam);
    await markSeen(sms);
  }

  /// The native SMS receiver reads the plain copy to stay quiet for spam senders.
  static Future<void> _saveSpam(
    SharedPreferences preferences,
    List<String> spam,
  ) async {
    await preferences.setStringList(_spamKey, spam);
    await preferences.setString('sms_spam_plain', spam.join(','));
  }

  /// Bank SMS notifications also need RECEIVE_SMS, which Android grants with READ_SMS.
  static Future<void> ensureReceivePermission() async {
    if (!await enabled()) return;
    if (!await Permission.sms.isGranted) await Permission.sms.request();
    final preferences = await SharedPreferences.getInstance();
    if (!preferences.containsKey('sms_spam_plain')) {
      await _saveSpam(preferences, preferences.getStringList(_spamKey) ?? []);
    }
  }

  static Future<List<String>> spamSenders() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_spamKey) ?? const [];
  }

  static Future<void> allowSender(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final spam = preferences.getStringList(_spamKey) ?? <String>[];
    spam.remove(key);
    await _saveSpam(preferences, spam);
  }
}

BankSms? alertFromNotification(ServiceNotificationEvent event) {
  if (event.hasRemoved || event.onGoing) return null;
  return parseUpiNotification(
    packageName: event.packageName,
    title: event.title,
    content: event.content,
    date: event.timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(event.timestamp)
        : DateTime.now(),
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
