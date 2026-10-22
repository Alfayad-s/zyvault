import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _ink = Color(0xFF17310C);
const _green = Color(0xFF3DDC84);

class StatementReview extends StatefulWidget {
  const StatementReview({
    super.key,
    required this.accountName,
    required this.rows,
    required this.categories,
    required this.onSave,
  });

  final String accountName;
  final List<StatementLine> rows;
  final List<Category> categories;
  final Future<int> Function(List<StatementLine> rows) onSave;

  @override
  State<StatementReview> createState() => _StatementReviewState();
}

class _StatementReviewState extends State<StatementReview> {
  late List<StatementLine> _rows;
  late List<bool> _checked;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rows = [...widget.rows];
    _checked = [for (final row in _rows) !row.duplicate];
  }

  List<_ReviewEntry> get _entries {
    final order = [for (var index = 0; index < _rows.length; index++) index]
      ..sort((a, b) => _rows[b].occurredOn.compareTo(_rows[a].occurredOn));
    final entries = <_ReviewEntry>[];
    String? month;
    for (final index in order) {
      final key = _rows[index].occurredOn.length >= 7 ? _rows[index].occurredOn.substring(0, 7) : _rows[index].occurredOn;
      if (key != month) {
        month = key;
        entries.add(_ReviewEntry.month(key));
      }
      entries.add(_ReviewEntry.row(index));
    }
    return entries;
  }

  List<StatementLine> get _chosen {
    final chosen = <StatementLine>[];
    for (var index = 0; index < _rows.length; index++) {
      if (_checked[index]) chosen.add(_rows[index]);
    }
    return chosen;
  }

  Future<void> _save() async {
    final chosen = _chosen;
    if (chosen.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.onSave(chosen);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (caught) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$caught';
        });
      }
    }
  }

  Future<void> _pickCategory(int index) async {
    final row = _rows[index];
    final options = widget.categories.where((category) => category.kind == row.kind).toList();
    final picked = await showModalBottomSheet<Category>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Category', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            for (final category in options)
              ListTile(
                leading: CategoryIcon(name: category.name, kind: category.kind, size: 36),
                title: Text(category.name, style: const TextStyle(color: Colors.white)),
                trailing: category.id == row.categoryId ? const Icon(LucideIcons.check, color: _lime) : null,
                onTap: () => Navigator.pop(context, category),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rows[index] = row.copyWith(categoryId: picked.id, categoryName: picked.name, kind: picked.kind, uncertain: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen;
    final out = chosen.where((row) => row.kind == 'expense').fold<int>(0, (sum, row) => sum + row.amount);
    final into = chosen.where((row) => row.kind == 'income').fold<int>(0, (sum, row) => sum + row.amount);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x),
                  ),
                  const Expanded(
                    child: Text('Check the statement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _entries.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.accountName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          '${chosen.length} to save · ${formatRupees(out)} out · ${formatRupees(into)} in',
                          style: const TextStyle(color: _muted, fontSize: 15),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B))),
                        ],
                        const SizedBox(height: 8),
                      ],
                    );
                  }
                  final entry = _entries[index - 1];
                  final month = entry.month;
                  if (month != null) {
                    final count = _rows.where((row) => row.occurredOn.startsWith(month)).length;
                    return Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        '${_monthLabel(month)} · $count',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    );
                  }
                  final rowIndex = entry.row!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RowCard(
                      row: _rows[rowIndex],
                      checked: _checked[rowIndex],
                      onCheck: _saving ? null : (value) => setState(() => _checked[rowIndex] = value),
                      onCategory: _saving ? null : () => _pickCategory(rowIndex),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving || chosen.isEmpty ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _lime,
                    foregroundColor: _ink,
                    disabledBackgroundColor: _line,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  child: Text(_saving ? 'Saving' : 'Save ${chosen.length}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewEntry {
  const _ReviewEntry.month(this.month) : row = null;
  const _ReviewEntry.row(this.row) : month = null;

  final String? month;
  final int? row;
}

String _monthLabel(String month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final parts = month.split('-');
  final year = int.tryParse(parts[0]);
  final index = int.tryParse(parts.length > 1 ? parts[1] : '');
  if (year == null || index == null || index < 1 || index > 12) return month;
  final today = DateTime.now();
  final name = names[index - 1];
  return year == today.year ? name : '$name $year';
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.row,
    required this.checked,
    required this.onCheck,
    required this.onCategory,
  });

  final StatementLine row;
  final bool checked;
  final ValueChanged<bool>? onCheck;
  final VoidCallback? onCategory;

  @override
  Widget build(BuildContext context) {
    final income = row.kind == 'income';
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: onCheck == null ? null : (value) => onCheck!(value ?? false),
              activeColor: _lime,
              checkColor: _ink,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      formatDate(row.occurredOn),
                      if (row.duplicate) 'Already saved',
                      if (row.uncertain) 'Check category',
                    ].join(' · '),
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${income ? '+' : '-'}${formatRupees(row.amount)}',
                  style: TextStyle(color: income ? _green : Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Material(
                  color: _field,
                  shape: const StadiumBorder(side: BorderSide(color: _line)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onCategory,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CategoryIcon(name: row.categoryName, kind: row.kind, size: 18),
                          const SizedBox(width: 4),
                          Text(row.categoryName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
