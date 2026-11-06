import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/reminders.dart';
import 'package:finance_track/screens/schedule_editor.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:finance_track/widgets/pull_refresh.dart';
import 'package:finance_track/widgets/shimmer.dart';
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
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (caught) {
      if (!mounted) return;
      final local = [...widget.ledger.planned]..sort((a, b) => a.nextOn.compareTo(b.nextOn));
      setState(() {
        if (local.isNotEmpty || widget.ledger.offline) {
          _items = local;
          _error = null;
        } else {
          _error = '$caught';
        }
      });
    }
  }

  Future<void> _edit({Schedule? existing}) async {
    if (widget.ledger.accounts.isEmpty) {
      _snack('Add an account first');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ScheduleEditor(ledger: widget.ledger, existing: existing),
    );
    if (saved == true) {
      await _load();
      Reminders.sync(_items ?? const []);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    final body = PullRefresh(
      onRefresh: _load,
      child: ListView(
        physics: pullPhysics,
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
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const ShimmerRows(
                count: 4,
                scroll: false,
                inset: 16,
                padding: EdgeInsets.symmetric(vertical: 6),
              ),
            )
          else if (items.isEmpty)
            _Empty(onAdd: () => _edit())
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
                      onEdit: () => _edit(existing: schedule),
                      onDelete: () => _delete(schedule),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
    final page = Stack(
      children: [
        body,
        Positioned(
          right: 20,
          bottom: widget.embedded ? 96 : 24,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFFC8F57A),
            foregroundColor: const Color(0xFF17310C),
            onPressed: () => _edit(),
            child: const Icon(LucideIcons.plus),
          ),
        ),
      ],
    );
    if (widget.embedded) return page;
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled & recurring')),
      body: page,
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  final Schedule schedule;
  final VoidCallback onEdit;
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
      onTap: onEdit,
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
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
      child: Column(
        children: [
          const Icon(LucideIcons.calendarClock, color: _muted, size: 44),
          const SizedBox(height: 16),
          const Text(
            'Nothing planned yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add rent, salary or any payment that happens on a date. You can also say it on the type page.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC8F57A),
              foregroundColor: const Color(0xFF17310C),
            ),
            child: const Text('Add a plan'),
          ),
        ],
      ),
    );
  }
}
