import 'dart:io';
import 'dart:math' as math;

import 'package:finance_track/access.dart';
import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/app_lock.dart';
import 'package:finance_track/haptics.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/person_profile.dart';
import 'package:finance_track/screens/settings_screen.dart';
import 'package:finance_track/widgets/pull_refresh.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

const _card = Color(0xFF2C2C2E);
const _muted = Color(0xFF8E8E93);
const _ink = Color(0xFF1E4D12);
const _lime = Color(0xFFC8F57A);

const _partOrder = [
  'savingsConsistency',
  'expenseToIncome',
  'budgetDiscipline',
  'recurringBurden',
  'emergencyReserve',
];

const _partLabels = {
  'savingsConsistency': 'Savings consistency',
  'expenseToIncome': 'Spending against income',
  'budgetDiscipline': 'Budget discipline',
  'recurringBurden': 'Recurring plans',
  'emergencyReserve': 'Emergency reserve',
};

class ProfileScreen extends StatefulWidget {
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
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<_HealthPart>? _parts;
  int? _score;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final body = await widget.ledger.api.financeHealth();
      if (!mounted) return;
      setState(() {
        _score = (body['score'] as num?)?.round();
        _parts = _readParts(body['components']);
        _error = null;
        _loading = false;
      });
    } on FinanceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _error = '$caught';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      widget.ledger.refresh(),
      PersonProfile.load(),
      ProfilePhoto.load(),
      AppAccess.current.load(widget.ledger.api),
      _load(),
    ]);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          ledger: widget.ledger,
          lock: widget.lock,
          onLogout: widget.onLogout,
          onCheckSms: widget.onCheckSms,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(LucideIcons.settings),
          ),
        ],
      ),
      body: PullRefresh(
        onRefresh: _refresh,
        child: ListView(
          physics: pullPhysics,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _ProfileHeader(score: _loading ? null : _score, waiting: _loading),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: _muted, height: 1.4)),
            ] else if (!_loading && _score != null && _lowestDetail(_parts ?? const []) != null) ...[
              const SizedBox(height: 14),
              Text(
                _lowestDetail(_parts ?? const [])!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 15, height: 1.4),
              ),
            ] else if (!_loading && _score == null) ...[
              const SizedBox(height: 14),
              const Text(
                'There is not enough history yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 15, height: 1.4),
              ),
            ],
            const SizedBox(height: 22),
            _AnalyticsBento(ledger: widget.ledger, parts: _parts ?? const []),
          ],
        ),
      ),
    );
  }
}

class _HealthPart {
  const _HealthPart({
    required this.id,
    required this.label,
    required this.score,
    required this.detail,
    required this.series,
  });

  final String id;
  final String label;
  final int? score;
  final String detail;
  final List<double> series;
}

List<_HealthPart> _readParts(Object? raw) {
  final byId = <String, _HealthPart>{};
  if (raw is List) {
    for (final item in raw) {
      if (item is! Map) continue;
      final id = item['id'] as String? ?? '';
      if (id.isEmpty) continue;
      byId[id] = _HealthPart(
        id: id,
        label: item['label'] as String? ?? _partLabels[id] ?? id,
        score: (item['score'] as num?)?.round(),
        detail: item['detail'] as String? ?? '',
        series: [
          for (final point in item['series'] as List<dynamic>? ?? const [])
            if (point is num) point.toDouble().clamp(0, 100).toDouble(),
        ],
      );
    }
  }
  return [
    for (final id in _partOrder)
      byId[id] ??
          _HealthPart(
            id: id,
            label: _partLabels[id] ?? id,
            score: null,
            detail: '',
            series: const [],
          ),
  ];
}

String _band(int score) {
  if (score >= 85) return 'Strong';
  if (score >= 70) return 'Good';
  if (score >= 40) return 'Fair';
  return 'Needs care';
}

String? _lowestDetail(List<_HealthPart> parts) {
  _HealthPart? lowest;
  for (final part in parts) {
    final score = part.score;
    if (score == null) continue;
    if (lowest == null || score < lowest.score!) lowest = part;
  }
  final detail = lowest?.detail.trim() ?? '';
  return detail.isEmpty ? null : detail;
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final track = Paint()
      ..color = const Color(0xFF3A3A3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    final value = progress;
    if (value == null || value <= 0) return;
    final arc = Paint()
      ..color = _lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value.clamp(0, 1),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.progress != progress;
}

class _AnalyticsBento extends StatelessWidget {
  const _AnalyticsBento({required this.ledger, required this.parts});

  final Ledger ledger;
  final List<_HealthPart> parts;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) {
        final summary = ledger.summary;
        final saved = summary == null
            ? null
            : summary.monthIncome - summary.monthExpense;
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: _BentoTile(
                    height: 148,
                    label: 'On hand',
                    value: summary == null ? '—' : '₹${formatMoney(summary.balance)}',
                    note: 'Cash and bank',
                    accent: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _BentoTile(
                        height: 69,
                        label: 'Income',
                        value: summary == null ? '—' : '₹${formatMoney(summary.monthIncome)}',
                      ),
                      const SizedBox(height: 10),
                      _BentoTile(
                        height: 69,
                        label: 'Spent',
                        value: summary == null ? '—' : '₹${formatMoney(summary.monthExpense)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _BentoTile(
              height: 96,
              label: 'Saved this month',
              value: saved == null
                  ? '—'
                  : '${saved < 0 ? '-' : ''}₹${formatMoney(saved.abs())}',
              note: saved != null && saved < 0 ? 'Spent more than came in' : 'Income minus spending',
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < parts.length; index += 2) ...[
              if (index > 0) const SizedBox(height: 10),
              if (index + 1 >= parts.length)
                _PartTile(part: parts[index])
              else
                Row(
                  children: [
                    Expanded(child: _PartTile(part: parts[index])),
                    const SizedBox(width: 10),
                    Expanded(child: _PartTile(part: parts[index + 1])),
                  ],
                ),
            ],
          ],
        );
      },
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.height,
    required this.label,
    required this.value,
    this.note,
    this.accent = false,
  });

  final double height;
  final String label;
  final String value;
  final String? note;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: accent ? _lime : _card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent ? _ink : _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent ? _ink : Colors.white,
              fontSize: height > 100 ? 26 : 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent ? _ink.withValues(alpha: 0.7) : _muted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PartTile extends StatelessWidget {
  const _PartTile({required this.part});

  final _HealthPart part;

  @override
  Widget build(BuildContext context) {
    final score = part.score;
    return Container(
      height: 128,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            part.label,
            maxLines: 2,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            score == null ? 'Not enough yet' : '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _Sparkline(
            values: part.series.isNotEmpty
                ? part.series
                : score == null
                ? const []
                : [score.toDouble(), score.toDouble()],
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(values)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final points = <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
          size.width * index / (values.length - 1),
          size.height - 2 - (values[index].clamp(0, 100) / 100) * (size.height - 4),
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final mid = Offset((current.dx + next.dx) / 2, (current.dy + next.dy) / 2);
      line.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    line.lineTo(points.last.dx, points.last.dy);
    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = _lime.withValues(alpha: 0.22));
    canvas.drawPath(
      line,
      Paint()
        ..color = _lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(points.last, 2.5, Paint()..color = _lime);
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => oldDelegate.values != values;
}

class _ProfileHeader extends StatefulWidget {
  const _ProfileHeader({required this.score, required this.waiting});

  final int? score;
  final bool waiting;

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  @override
  void initState() {
    super.initState();
    PersonProfile.load();
    ProfilePhoto.load();
  }

  Future<void> _editName() async {
    final person = PersonProfile.current.value;
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _NameSheet(initial: person.name),
    );
    if (saved == null || !mounted) return;
    await PersonProfile(
      name: saved,
      age: person.age,
      working: person.working,
      salaryRupees: person.salaryRupees,
      payday: person.payday,
      startedOn: person.startedOn,
    ).save();
  }

  Future<void> _editStarted(PersonProfile person) async {
    final current = DateTime.tryParse(person.startedOn ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    await PersonProfile(
      name: person.name,
      age: person.age,
      working: person.working,
      salaryRupees: person.salaryRupees,
      payday: person.payday,
      startedOn: '${picked.year}-$month-$day',
    ).save();
  }

  Future<void> _choose() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera, color: Colors.white),
              title: const Text('Take a photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, color: Colors.white),
              title: const Text('Choose a photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.user, color: Colors.white),
              title: const Text('Change name', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'name'),
            ),
            if (ProfilePhoto.current.value != null)
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: Color(0xFFFF6B6B)),
                title: const Text('Remove photo', style: TextStyle(color: Color(0xFFFF6B6B))),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      await ProfilePhoto.clear();
      return;
    }
    if (choice == 'name') {
      await _editName();
      return;
    }
    try {
      final shot = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (shot == null || !mounted) return;
      final folder = await getApplicationDocumentsDirectory();
      final saved = File('${folder.path}/profile-photo.jpg');
      await File(shot.path).copy(saved.path);
      await FileImage(saved).evict();
      await ProfilePhoto.remember(saved.path);
    } catch (error) {
      debugPrint('Profile photo: $error');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Could not save that photo. Try again')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: ProfilePhoto.current,
      builder: (context, path, _) => ValueListenableBuilder<PersonProfile>(
        valueListenable: PersonProfile.current,
        builder: (context, person, _) {
          final started = person.startedOn;
          final score = widget.score;
          return Column(
            children: [
              GestureDetector(
                onTap: withTapHaptic(_choose),
                child: SizedBox(
                  width: 148,
                  height: 148,
                  child: CustomPaint(
                    painter: _RingPainter(
                      widget.waiting || score == null ? null : score / 100,
                    ),
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: _lime,
                            backgroundImage: path == null ? null : FileImage(File(path)),
                            child: path == null
                                ? const Icon(LucideIcons.user, size: 36, color: Color(0xFF17310C))
                                : null,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF17310C),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF161616), width: 2),
                              ),
                              child: const Icon(LucideIcons.camera, size: 14, color: _lime),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.waiting ? 'Score' : score == null ? 'No score yet' : '$score · ${_band(score)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      person.name.isEmpty ? 'Your name' : person.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit name',
                    onPressed: _editName,
                    icon: const Icon(LucideIcons.pencil, size: 18, color: _lime),
                  ),
                ],
              ),
              if (started != null)
                GestureDetector(
                  onTap: () => _editStarted(person),
                  child: Text(
                    'Since ${formatStarted(started)}',
                    style: const TextStyle(color: _muted, fontSize: 15),
                  ),
                ),
              if (person.age != null)
                Text(
                  '${person.age} years',
                  style: const TextStyle(color: _muted, fontSize: 15),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});

  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Your name',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Name',
              filled: true,
              fillColor: _card,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, _name.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: const Color(0xFF17310C),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
