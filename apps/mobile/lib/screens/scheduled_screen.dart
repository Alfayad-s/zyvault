import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/reminders.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _muted = Color(0xFF8E8E93);

class ScheduledScreen extends StatefulWidget {
  const ScheduledScreen({
    super.key,
    required this.ledger,
    this.embedded = false,
  });

  final Ledger ledger;

  /// Shown as a bottom-bar tab inside the shell's scaffold.
  final bool embedded;

  @override
  State<ScheduledScreen> createState() => _ScheduledScreenState();
}

class _ScheduledScreenState extends State<ScheduledScreen> {
  List<Schedule>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.ledger.schedules();
      if (mounted) setState(() => _items = items);
    } catch (caught) {
      if (mounted) setState(() => _error = '$caught');
    }
  }

  Future<void> _delete(Schedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Stop this plan?'),
        content: Text(
          schedule.monthly
              ? 'It will no longer be added every month. Entries already saved stay.'
              : 'It will not be added on ${formatDate(schedule.nextOn)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Stop',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.ledger.deleteSchedule(schedule.id);
      await _load();
      Reminders.sync(_items ?? const []);
    } catch (caught) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$caught')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, widget.embedded ? 120 : 40),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFF6B6B)),
              ),
            )
          else if (items == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            const _Empty()
          else
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  for (final (index, schedule) in items.indexed) ...[
                    if (index > 0)
                      const Divider(height: 1, color: Color(0xFF3A3A3C)),
                    _ScheduleRow(
                      schedule: schedule,
                      onDelete: () => _delete(schedule),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled & recurring')),
      body: body,
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.schedule, required this.onDelete});

  final Schedule schedule;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final income = schedule.kind == 'income';
    final at = schedule.atTime == null
        ? ''
        : ' at ${formatClock(schedule.atTime!)}';
    final when = schedule.monthly
        ? 'Every month on day ${schedule.dayOfMonth}$at · next ${formatDate(schedule.nextOn)}'
        : 'Once on ${formatDate(schedule.nextOn)}$at';
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      leading: CategoryIcon(
        name: schedule.categoryName,
        kind: schedule.kind,
        size: 40,
      ),
      title: Text(
        schedule.note ?? schedule.categoryName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(when, style: const TextStyle(color: _muted, fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${income ? '+' : ''}${formatRupees(schedule.amount)}',
            style: TextStyle(
              color: income ? const Color(0xFF3DDC84) : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'Stop',
            onPressed: onDelete,
            icon: const Icon(LucideIcons.trash2, color: _muted, size: 20),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 64, 24, 24),
      child: Column(
        children: [
          Icon(LucideIcons.calendarClock, color: _muted, size: 44),
          SizedBox(height: 16),
          Text(
            'Nothing planned yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'On the type page, say or type things like\n“every month I get 35k salary on 1st”\nor “next month 6th I will get 5000 from Ravi”',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
