import 'dart:io' show Platform;

import 'package:finance_track/money.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// The Android home-screen widget: balance, this month's spending, and
/// Speak / Type buttons that open the type page.
class HomeScreenWidget {
  static const _provider = 'FinanceWidgetProvider';
  static String? _shown;

  static bool get supported =>
      !kIsWeb &&
      Platform.isAndroid &&
      !Platform.environment.containsKey('FLUTTER_TEST');

  static ({String title, String balance, String spent}) texts({
    required int balance,
    required int spentThisMonth,
    required int accounts,
    required bool hidden,
  }) {
    final title = accounts == 1 ? '1 account' : 'All accounts';
    if (hidden) {
      return (
        title: title,
        balance: '₹ ••••',
        spent: 'Amounts hidden while app lock is on',
      );
    }
    return (
      title: title,
      balance: balance < 0
          ? '- ${formatRupees(-balance)}'
          : formatRupees(balance),
      spent: 'Spent ${formatRupees(spentThisMonth)} this month',
    );
  }

  static Future<void> update({
    required int balance,
    required int spentThisMonth,
    required int accounts,
    required bool hidden,
  }) async {
    if (!supported) return;
    final shown = texts(
      balance: balance,
      spentThisMonth: spentThisMonth,
      accounts: accounts,
      hidden: hidden,
    );
    final key = '${shown.title}|${shown.balance}|${shown.spent}';
    if (key == _shown) return;
    try {
      await HomeWidget.saveWidgetData<String>('widget_title', shown.title);
      await HomeWidget.saveWidgetData<String>('widget_balance', shown.balance);
      await HomeWidget.saveWidgetData<String>('widget_spent', shown.spent);
      await HomeWidget.updateWidget(androidName: _provider);
      _shown = key;
    } catch (caught) {
      debugPrint('Home widget update failed: $caught');
    }
  }

  static Future<Uri?> launchedWith() async {
    if (!supported) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  static Stream<Uri?> get clicks =>
      supported ? HomeWidget.widgetClicked : const Stream.empty();
}
