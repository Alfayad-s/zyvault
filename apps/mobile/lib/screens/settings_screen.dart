import 'package:finance_track/access.dart';
import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/app_lock.dart';
import 'package:finance_track/build_flags.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/notifications.dart';
import 'package:finance_track/push.dart';
import 'package:finance_track/reminders.dart';
import 'package:finance_track/reply_voice.dart';
import 'package:finance_track/screens/admin_panel_screen.dart';
import 'package:finance_track/screens/categories_screen.dart';
import 'package:finance_track/screens/review_sheet.dart';
import 'package:finance_track/screens/server_status_screen.dart';
import 'package:finance_track/sms/sms_inbox.dart';
import 'package:finance_track/widgets/pull_refresh.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _muted = Color(0xFF8E8E93);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: AppAccess.current,
        builder: (context, _) => PullRefresh(
        onRefresh: ledger.refresh,
        child: ListView(
          physics: pullPhysics,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (AppAccess.current.isAdmin) ...[
              _SettingsSection(
                title: 'Admin',
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.shield, color: Colors.white),
                    title: const Text('Admin panel', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Turn public features on or off for members',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, color: _muted),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminPanelScreen(api: ledger.api),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
            ],
            if (lock != null) ...[
              _SettingsSection(
                title: 'Security',
                children: [
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
                ],
              ),
              const SizedBox(height: 22),
            ],
            _SettingsSection(
              title: 'Money',
              children: [
                const _ReviewSwitch(),
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
              ],
            ),
            const SizedBox(height: 22),
            _SettingsSection(
              title: 'Voice',
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.languages, color: Colors.white),
                  title: const Text(
                    'Install Malayalam speech',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Opens Google’s voice download so Read can speak Malayalam',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  trailing: const Icon(LucideIcons.chevronRight, color: _muted),
                  onTap: () async {
                    final problem = await ReplyVoice.openMalayalamInstall();
                    if (problem != null && context.mounted) {
                      _show(context, problem);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            _AlertSettings(ledger: ledger, onCheckSms: onCheckSms),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ServerStatusScreen(api: ledger.api),
                  ),
                ),
                child: const Text(
                  'Server details',
                  style: TextStyle(color: Color(0xFFC8F57A)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () => _clearData(context),
                icon: const Icon(LucideIcons.trash2),
                label: const Text('Remove all data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B6B),
                  side: const BorderSide(color: Color(0xFF3A3A3C)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
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
        ),
      ),
      ),
    );
  }

  Future<void> _clearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Remove all data?'),
        content: const Text(
          'Payments, accounts, budgets, plans, people, and goals will be deleted. Your name, photo, and sign-in stay. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove data',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ledger.clearRecords();
      if (context.mounted) _show(context, 'Your data was removed');
    } on FinanceException catch (error) {
      if (context.mounted) _show(context, error.message);
    } catch (caught) {
      if (context.mounted) _show(context, '$caught');
    }
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

void _show(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        rows.add(const Divider(height: 1, color: Color(0xFF3A3A3C)));
      }
      rows.add(children[index]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(children: rows),
        ),
      ],
    );
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
        _show(context, problem);
        return;
      }
      setState(() => _apps = true);
      await _afterAlertsOn();
    } catch (_) {
      if (!mounted) return;
      _show(context, 'Could not turn on UPI app alerts. Try again');
    }
  }

  Future<void> _afterAlertsOn() async {
    try {
      await Notifier.askPermission();
    } catch (error) {
      debugPrint('Notification permission: $error');
    }
    try {
      await widget.onCheckSms?.call();
    } catch (error) {
      debugPrint('Payment alert watch: $error');
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
        _show(context, problem);
        return;
      }
      setState(() => _sms = true);
      await _afterAlertsOn();
    } catch (_) {
      if (!mounted) return;
      _show(context, 'Could not turn on bank SMS. Try again');
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
        _SettingsSection(
          title: 'Alerts',
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
        if (SmsInbox.supported &&
            (AppAccess.current.on('bankSms') || AppAccess.current.on('upiAlerts')))
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
        if (SmsInbox.supported && AppAccess.current.on('bankSms')) ...[
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
          if (upiAlertsBuild && AppAccess.current.on('upiAlerts'))
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
            ],
          ],
        ),
        const SizedBox(height: 22),
        _SettingsSection(
          title: 'Spam',
          children: _spam.isEmpty
              ? const [
                  ListTile(
                    leading: Icon(LucideIcons.shield, color: Colors.white),
                    title: Text(
                      'No spam senders',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'A sender you mark as spam on a payment alert is listed here',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ),
                ]
              : [
                  for (final sender in _spam)
                    ListTile(
                      leading: const Icon(
                        LucideIcons.shieldAlert,
                        color: Color(0xFFFF6B6B),
                      ),
                      title: Text(sender, style: title),
                      subtitle: const Text(
                        'Payment alerts from this sender are skipped',
                        style: subtitle,
                      ),
                      trailing: TextButton(
                        onPressed: () => _allow(sender),
                        child: const Text('Allow'),
                      ),
                    ),
                ],
        ),
      ],
    );
  }
}
