import 'package:finance_track/app_lock.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/notifications.dart';
import 'package:finance_track/push.dart';
import 'package:finance_track/reminders.dart';
import 'package:finance_track/screens/categories_screen.dart';
import 'package:finance_track/screens/review_sheet.dart';
import 'package:finance_track/sms/sms_inbox.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _muted = Color(0xFF8E8E93);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.ledger,
    required this.onLogout,
    this.lock,
    this.onCheckSms,
  });

  final Ledger ledger;
  final AppLock? lock;
  final Future<void> Function() onLogout;
  final Future<void> Function()? onCheckSms;

  @override
  Widget build(BuildContext context) {
    final lock = this.lock;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              if (lock != null)
                ListenableBuilder(
                  listenable: lock,
                  builder: (context, _) => SwitchListTile(
                    value: lock.enabled,
                    onChanged: (value) => _toggleLock(context, lock, value),
                    secondary: const Icon(
                      LucideIcons.fingerprint,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Unlock with fingerprint',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Ask for fingerprint, face or phone PIN when the app opens',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                    activeThumbColor: const Color(0xFF17310C),
                    activeTrackColor: const Color(0xFFC8F57A),
                  ),
                ),
              if (lock != null)
                const Divider(height: 1, color: Color(0xFF3A3A3C)),
              const _ReviewSwitch(),
              const Divider(height: 1, color: Color(0xFF3A3A3C)),
              ListTile(
                leading: const Icon(LucideIcons.tags, color: Colors.white),
                title: const Text(
                  'Categories',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Add your own with a 3D icon',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                trailing: const Icon(LucideIcons.chevronRight, color: _muted),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CategoriesScreen(ledger: ledger),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFF3A3A3C)),
              _AlertSettings(ledger: ledger, onCheckSms: onCheckSms),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(LucideIcons.logOut),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF6B6B),
              side: const BorderSide(color: Color(0xFF3A3A3C)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleLock(
    BuildContext context,
    AppLock lock,
    bool value,
  ) async {
    final problem = await lock.setEnabled(value);
    if (problem != null && context.mounted) _show(context, problem);
  }
}

class _ReviewSwitch extends StatefulWidget {
  const _ReviewSwitch();

  @override
  State<_ReviewSwitch> createState() => _ReviewSwitchState();
}

class _ReviewSwitchState extends State<_ReviewSwitch> {
  bool? _on;

  @override
  void initState() {
    super.initState();
    loadReviewBeforeSave().then((value) {
      if (mounted) setState(() => _on = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: _on ?? true,
      onChanged: _on == null
          ? null
          : (value) {
              setState(() => _on = value);
              saveReviewBeforeSave(value);
            },
      secondary: const Icon(LucideIcons.listChecks, color: Colors.white),
      title: const Text(
        'Review before saving',
        style: TextStyle(color: Colors.white),
      ),
      subtitle: const Text(
        'Check what the AI understood, then tap Save',
        style: TextStyle(color: _muted, fontSize: 13),
      ),
      activeThumbColor: const Color(0xFF17310C),
      activeTrackColor: const Color(0xFFC8F57A),
    );
  }
}

class _AlertSettings extends StatefulWidget {
  const _AlertSettings({required this.ledger, this.onCheckSms});

  final Ledger ledger;
  final Future<void> Function()? onCheckSms;

  @override
  State<_AlertSettings> createState() => _AlertSettingsState();
}

class _AlertSettingsState extends State<_AlertSettings> {
  var _reminders = true;
  var _payments = true;
  var _budgets = true;
  var _serverPush = false;
  var _sms = false;
  var _apps = false;
  var _spam = <String>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reminders = await Reminders.enabled();
    final payments = await Notifier.isOn(paymentAlertsKey);
    final budgets = await Notifier.isOn(budgetAlertsKey);
    final serverPush = await Push.serverHandlesReminders();
    final sms = await SmsInbox.enabled();
    final apps = await SmsInbox.appsEnabled();
    final spam = SmsInbox.supported ? await SmsInbox.spamSenders() : <String>[];
    if (!mounted) return;
    setState(() {
      _reminders = reminders;
      _payments = payments;
      _budgets = budgets;
      _serverPush = serverPush;
      _sms = sms;
      _apps = apps;
      _spam = spam;
    });
  }

  Future<void> _setApps(bool value) async {
    if (!value) {
      await SmsInbox.disableApps();
      if (mounted) setState(() => _apps = false);
      return;
    }
    try {
      final problem = await SmsInbox.enableApps();
      if (!mounted) return;
      if (problem != null) {
        ProfileScreen._show(context, problem);
        return;
      }
      setState(() => _apps = true);
      await Notifier.askPermission();
      await widget.onCheckSms?.call();
    } catch (_) {
      if (!mounted) return;
      ProfileScreen._show(context, 'Could not turn on UPI app alerts. Try again');
    }
  }

  Future<void> _setPayments(bool value) async {
    setState(() => _payments = value);
    await Notifier.setOn(paymentAlertsKey, value);
  }

  Future<void> _setBudgets(bool value) async {
    setState(() => _budgets = value);
    await Notifier.setOn(budgetAlertsKey, value);
  }

  Future<void> _setReminders(bool value) async {
    setState(() => _reminders = value);
    final schedules = await widget.ledger.schedules().catchError(
      (_) => <Schedule>[],
    );
    await Reminders.setEnabled(value, schedules);
  }

  Future<void> _setSms(bool value) async {
    if (!value) {
      await SmsInbox.disable();
      if (mounted) setState(() => _sms = false);
      return;
    }
    try {
      final problem = await SmsInbox.enable();
      if (!mounted) return;
      if (problem != null) {
        ProfileScreen._show(context, problem);
        return;
      }
      setState(() => _sms = true);
      await Notifier.askPermission();
      await widget.onCheckSms?.call();
    } catch (_) {
      if (!mounted) return;
      ProfileScreen._show(context, 'Could not turn on bank SMS. Try again');
    }
  }

  Future<void> _allow(String sender) async {
    await SmsInbox.allowSender(sender);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    const title = TextStyle(color: Colors.white);
    const subtitle = TextStyle(color: _muted, fontSize: 13);
    return Column(
      children: [
        SwitchListTile(
          value: _reminders,
          onChanged: _setReminders,
          secondary: const Icon(LucideIcons.bellRing, color: Colors.white),
          title: const Text('Bill & salary reminders', style: title),
          subtitle: const Text(
            'Notify the day before a bill, on salary day, and at the time you planned',
            style: subtitle,
          ),
          activeThumbColor: const Color(0xFF17310C),
          activeTrackColor: const Color(0xFFC8F57A),
        ),
        ListTile(
          leading: Icon(
            _serverPush ? LucideIcons.cloudCheck : LucideIcons.cloudOff,
            color: Colors.white,
          ),
          title: const Text('Server push', style: title),
          subtitle: Text(
            _serverPush
                ? 'On: planned entries, bills due tomorrow and a Sunday summary arrive even when the app is closed'
                : 'Off: reminders come from this phone only. Push turns on once Firebase is set up',
            style: subtitle,
          ),
        ),
        const Divider(height: 1, color: Color(0xFF3A3A3C)),
        SwitchListTile(
          value: _budgets,
          onChanged: _setBudgets,
          secondary: const Icon(LucideIcons.gauge, color: Colors.white),
          title: const Text('Budget alerts', style: title),
          subtitle: const Text(
            'Notify when a category reaches 80% and when it goes over',
            style: subtitle,
          ),
          activeThumbColor: const Color(0xFF17310C),
          activeTrackColor: const Color(0xFFC8F57A),
        ),
        if (SmsInbox.supported) ...[
          const Divider(height: 1, color: Color(0xFF3A3A3C)),
          SwitchListTile(
            value: _payments,
            onChanged: _setPayments,
            secondary: const Icon(LucideIcons.bellPlus, color: Colors.white),
            title: const Text('New payment notifications', style: title),
            subtitle: const Text(
              'A bank SMS or UPI app shows a payment? Get a notification to save it, even when the app is closed',
              style: subtitle,
            ),
            activeThumbColor: const Color(0xFF17310C),
            activeTrackColor: const Color(0xFFC8F57A),
          ),
        ],
        if (SmsInbox.supported) ...[
          const Divider(height: 1, color: Color(0xFF3A3A3C)),
          SwitchListTile(
            value: _sms,
            onChanged: _setSms,
            secondary: const Icon(
              LucideIcons.messageSquareText,
              color: Colors.white,
            ),
            title: const Text('Read bank SMS', style: title),
            subtitle: const Text(
              'When a bank text arrives, its notification asks where the money went. The message stays on this phone.',
              style: subtitle,
            ),
            activeThumbColor: const Color(0xFF17310C),
            activeTrackColor: const Color(0xFFC8F57A),
          ),
          const Divider(height: 1, color: Color(0xFF3A3A3C)),
          SwitchListTile(
            value: _apps,
            onChanged: _setApps,
            secondary: const Icon(LucideIcons.smartphone, color: Colors.white),
            title: const Text('Read UPI app alerts', style: title),
            subtitle: const Text(
              'GPay, PhonePe, Paytm, BHIM and CRED payments, the moment they arrive',
              style: subtitle,
            ),
            activeThumbColor: const Color(0xFF17310C),
            activeTrackColor: const Color(0xFFC8F57A),
          ),
          for (final sender in _spam)
            ListTile(
              dense: true,
              leading: const Icon(
                LucideIcons.shieldAlert,
                color: Color(0xFFFF6B6B),
                size: 20,
              ),
              title: Text('Spam: $sender', style: title),
              trailing: TextButton(
                onPressed: () => _allow(sender),
                child: const Text('Allow'),
              ),
            ),
        ],
      ],
    );
  }
}
