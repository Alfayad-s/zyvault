import 'dart:io' show Platform;

import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/sms/bank_sms.dart';
import 'package:finance_track/sms/sms_inbox.dart' show senderKey;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const paymentAlertsKey = 'payment_alerts';
const budgetAlertsKey = 'budget_alerts';
const _budgetSentKey = 'budget_alerts_sent';
const _foregroundKey = 'foreground_at';

/// Notification ids: reminders use 1000-1999, payments 3,000,000+, budgets 4,000,000+.
const reminderIds = (start: 1000, end: 2000);
const _paymentBase = 3000000;
const _budgetBase = 4000000;

/// Phone notifications for new payments, budgets and (via Reminders) plans.
class Notifier {
  Notifier._();

  static final plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _ready;

  static bool get _supported =>
      (Platform.isAndroid || Platform.isIOS) &&
      !Platform.environment.containsKey('FLUTTER_TEST');

  static Future<void> init() {
    return _ready ??= plugin
        .initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_payment'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        )
        .then((_) {});
  }

  static Future<bool> isOn(String key) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(key) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setOn(String key, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
    if (value) await askPermission();
  }

  static Future<void> askPermission() async {
    if (!_supported) return;
    try {
      await init();
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
    } catch (error) {
      debugPrint('Could not ask for notifications: $error');
    }
  }

  /// Lets the native SMS receiver skip notifying while the app is on screen.
  static Future<void> markForeground(bool foreground) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(
        _foregroundKey,
        foreground ? DateTime.now().millisecondsSinceEpoch : 0,
      );
    } catch (_) {}
  }

  static String paymentTitle(BankSms alert) {
    final amount = formatRupees(alert.amount);
    final from = alert.app ?? senderKey(alert.sender);
    return alert.kind == 'income'
        ? '$amount received · $from'
        : '$amount debited · $from';
  }

  static Future<void> payment(BankSms alert) async {
    if (!_supported || !await isOn(paymentAlertsKey)) return;
    await _show(
      id: _paymentBase + (alert.id.hashCode & 0xFFFFF),
      channel: 'payments',
      channelName: 'New payments',
      title: paymentTitle(alert),
      body: alert.merchant == null
          ? 'Tap to save it in zyvault'
          : '${alert.merchant} · tap to save it',
    );
  }

  /// Which budget warnings are new: 80% used, then over the limit, once each per month.
  static List<({Budget budget, bool over})> newBudgetAlerts(
    List<Budget> budgets,
    Set<String> sent,
  ) {
    return [
      for (final budget in budgets)
        if (budget.over &&
            !sent.contains('${budget.month}:${budget.categoryId}:100'))
          (budget: budget, over: true)
        else if (!budget.over &&
            budget.used >= 0.8 &&
            !sent.contains('${budget.month}:${budget.categoryId}:80'))
          (budget: budget, over: false),
    ];
  }

  static Future<void> budgets(List<Budget> budgets) async {
    if (!_supported || budgets.isEmpty || !await isOn(budgetAlertsKey)) return;
    final preferences = await SharedPreferences.getInstance();
    final sent = (preferences.getStringList(_budgetSentKey) ?? const [])
        .toSet();
    final fresh = newBudgetAlerts(budgets, sent);
    if (fresh.isEmpty) return;
    for (final (:budget, :over) in fresh) {
      final key = '${budget.month}:${budget.categoryId}:${over ? 100 : 80}';
      sent
        ..add(key)
        ..add('${budget.month}:${budget.categoryId}:80');
      await _show(
        id: _budgetBase + (key.hashCode & 0xFFFFF),
        channel: 'budgets',
        channelName: 'Budget alerts',
        title: over
            ? '${budget.categoryName} budget is over'
            : '${budget.categoryName} budget ${(budget.used * 100).round()}% used',
        body: over
            ? 'Spent ${formatRupees(budget.spent)} of ${formatRupees(budget.limitAmount)}, ${formatRupees(-budget.left)} over'
            : '${formatRupees(budget.left)} left of ${formatRupees(budget.limitAmount)} this month',
      );
    }
    final kept = sent.toList()..sort();
    await preferences.setStringList(
      _budgetSentKey,
      kept.length > 200 ? kept.sublist(kept.length - 200) : kept,
    );
  }

  /// Channels for pushes from the server; Android needs them before the first push.
  static Future<void> createPushChannels() async {
    if (!_supported) return;
    await init();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'plans',
        'Planned payments',
        description:
            'Bills due tomorrow and planned entries the app saved for you',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'summaries',
        'Weekly summary',
        description: 'How much you spent this week',
      ),
    );
  }

  /// Shows a push that arrived while the app is open (Android only shows them in the background).
  static Future<void> pushInForeground({
    required String title,
    required String body,
    required String channel,
  }) => _show(
    id: 5000000 + ('$title$body'.hashCode & 0xFFFFF),
    channel: channel,
    channelName: channel == 'summaries' ? 'Weekly summary' : 'Planned payments',
    title: title,
    body: body,
  );

  static Future<void> _show({
    required int id,
    required String channel,
    required String channelName,
    required String title,
    required String body,
  }) async {
    try {
      await init();
      await plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFFC8F57A),
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (caught) {
      debugPrint('Notification failed: $caught');
    }
  }
}
