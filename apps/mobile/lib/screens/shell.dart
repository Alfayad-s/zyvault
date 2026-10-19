import 'dart:async';

import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/app_lock.dart';
import 'package:finance_track/home_screen_widget.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/notifications.dart';
import 'package:finance_track/push.dart';
import 'package:finance_track/reminders.dart';
import 'package:finance_track/screens/accounts_screen.dart';
import 'package:finance_track/screens/chat_screen.dart';
import 'package:finance_track/screens/home_screen.dart';
import 'package:finance_track/screens/profile_screen.dart';
import 'package:finance_track/screens/scheduled_screen.dart';
import 'package:finance_track/screens/transaction_form_screen.dart';
import 'package:finance_track/screens/search_screen.dart';
import 'package:finance_track/screens/transactions_screen.dart';
import 'package:finance_track/screens/type_page.dart';
import 'package:finance_track/sms/sms_inbox.dart';
import 'package:finance_track/sms/sms_review_sheet.dart';
import 'package:finance_track/widgets/finance_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.api,
    required this.onLogout,
    this.lock,
  });

  final FinanceApi api;
  final Future<void> Function() onLogout;
  final AppLock? lock;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late final Ledger ledger;
  var _index = 0;
  var _reviewingSms = false;
  var _foreground = true;
  Timer? _smsPoll;
  StreamSubscription<ServiceNotificationEvent>? _upiAlerts;
  StreamSubscription<Uri?>? _widgetClicks;
  Uri? _lastWidgetLink;
  DateTime? _lastWidgetAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ledger = Ledger(widget.api, onUnauthorized: widget.onLogout);
    ledger.addListener(_onLedger);
    widget.lock?.addListener(_pushHomeWidget);
    Notifier.markForeground(true);
    _widgetClicks = HomeScreenWidget.clicks.listen(_openFromWidget);
    HomeScreenWidget.launchedWith().then(_openFromWidget);
    ledger.refresh().then((_) async {
      await Push.start(widget.api);
      _syncReminders();
      _watchMoneyAlerts();
    });
  }

  Future<void> _watchMoneyAlerts() async {
    if (!SmsInbox.supported) return;
    await SmsInbox.ensureReceivePermission();
    _startPolling();
    final watchSms = await SmsInbox.enabled();
    final watchApps = await SmsInbox.appsEnabled();
    if (_upiAlerts == null && (watchSms || watchApps)) {
      _upiAlerts = NotificationListenerService.notificationsStream.listen((
        event,
      ) async {
        final alert = alertFromNotification(event);
        if (alert == null) return;
        final added = await SmsInbox.storeAppAlert(alert);
        if (!added) return;
        if (_foreground) {
          _checkBankSms();
        } else {
          Notifier.payment(alert);
        }
      }, onError: (Object caught) => debugPrint('UPI alerts stopped: $caught'));
    }
    await _checkBankSms();
  }

  void _startPolling() {
    _smsPoll?.cancel();
    _smsPoll = Timer.periodic(const Duration(seconds: 20), (_) {
      Notifier.markForeground(true);
      _checkBankSms();
    });
  }

  String? _budgetsSeen;

  void _onLedger() {
    _pushHomeWidget();
    if (ledger.loading) return;
    final seen = [
      for (final budget in ledger.budgets)
        '${budget.id}:${budget.spent}:${budget.limitAmount}',
    ].join('|');
    if (seen == _budgetsSeen) return;
    _budgetsSeen = seen;
    Notifier.budgets(ledger.budgets);
  }

  void _pushHomeWidget() {
    final summary = ledger.summary;
    if (summary == null) return;
    HomeScreenWidget.update(
      balance: summary.balance,
      spentThisMonth: summary.monthExpense,
      accounts: ledger.accounts.length,
      hidden: widget.lock?.enabled ?? false,
    );
  }

  Future<void> _openFromWidget(Uri? link) async {
    if (link == null || link.host != 'type' || !mounted) return;
    final now = DateTime.now();
    if (link == _lastWidgetLink &&
        _lastWidgetAt != null &&
        now.difference(_lastWidgetAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastWidgetLink = link;
    _lastWidgetAt = now;
    await _waitForUnlock();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await openTypePage(
      context,
      ledger,
      startVoice: link.queryParameters['voice'] == '1',
    );
  }

  Future<void> _waitForUnlock() async {
    final lock = widget.lock;
    if (lock == null || !lock.locked) return;
    final unlocked = Completer<void>();
    void check() {
      if (!lock.locked && !unlocked.isCompleted) unlocked.complete();
    }

    lock.addListener(check);
    await unlocked.future;
    lock.removeListener(check);
  }

  Future<void> _syncReminders() async {
    try {
      Reminders.sync(await ledger.schedules());
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _smsPoll?.cancel();
    _upiAlerts?.cancel();
    _widgetClicks?.cancel();
    widget.lock?.removeListener(_pushHomeWidget);
    ledger.removeListener(_onLedger);
    ledger.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      Notifier.markForeground(true);
      ledger.catchUpSchedules();
      if (ledger.summary == null && !ledger.loading) ledger.refresh();
      _watchMoneyAlerts();
      _syncReminders();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      Notifier.markForeground(false);
      _smsPoll?.cancel();
    }
  }

  Future<void> _checkBankSms() async {
    if (_reviewingSms || !mounted || !_foreground || !SmsInbox.supported) {
      return;
    }
    if (ledger.accounts.isEmpty || ledger.categories.isEmpty) return;
    _reviewingSms = true;
    try {
      final pending = await SmsInbox.pending();
      if (pending.isEmpty || !mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await reviewBankSms(context, ledger: ledger, messages: pending);
    } catch (error) {
      debugPrint('Could not open a payment: $error');
    } finally {
      _reviewingSms = false;
    }
  }

  void _openTransaction(String kind) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            TransactionFormScreen(ledger: ledger, initialKind: kind),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ProfileScreen(
            ledger: ledger,
            lock: widget.lock,
            onLogout: () async {
              Navigator.of(context).popUntil((route) => route.isFirst);
              await Push.stop(widget.api);
              await widget.onLogout();
            },
            onCheckSms: _watchMoneyAlerts,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        ledger: ledger,
        onReceive: () => _openTransaction('income'),
        onSend: () => _openTransaction('expense'),
        onOpenRecords: () => setState(() => _index = 1),
        onOpenScheduled: () => setState(() => _index = 3),
        onOpenTransaction: (transaction) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) =>
                  TransactionFormScreen(ledger: ledger, existing: transaction),
            ),
          );
        },
      ),
      TransactionsScreen(ledger: ledger),
      AccountsScreen(ledger: ledger),
      ScheduledScreen(ledger: ledger, embedded: true),
    ];
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Search',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => SearchScreen(ledger: ledger),
              ),
            );
          },
          icon: const Icon(LucideIcons.search),
        ),
        title: Text(FinanceBottomBar.labels[_index]),
        actions: [
          IconButton(
            tooltip: 'Chat',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => ChatScreen(api: widget.api),
                ),
              );
            },
            icon: const Icon(LucideIcons.messageCircle),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Profile',
              onPressed: _openProfile,
              icon: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF3A3A3C),
                child: Icon(LucideIcons.user, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: FinanceBottomBar(
        index: _index,
        onChanged: (index) => setState(() => _index = index),
        onAdd: () => _openTransaction('expense'),
      ),
    );
  }
}
