import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _ink = Color(0xFF17310C);

class BillReview extends StatefulWidget {
  const BillReview({
    super.key,
    required this.imageBytes,
    required this.drafts,
    required this.categories,
    required this.saving,
    required this.error,
    required this.onSave,
    required this.onCancel,
  });

  final Uint8List? imageBytes;
  final List<ParsedSpend> drafts;
  final List<Category> categories;
  final bool saving;
  final String? error;
  final Future<void> Function(List<ParsedSpend> drafts) onSave;
  final VoidCallback onCancel;

  @override
  State<BillReview> createState() => _BillReviewState();
}

class _BillReviewState extends State<BillReview> {
  late List<ParsedSpend> _drafts;
  late final List<TextEditingController> _amounts;

  @override
  void initState() {
    super.initState();
    _drafts = [for (final draft in widget.drafts) _matched(draft)];
    _amounts = [
      for (final draft in _drafts) TextEditingController(text: _amountText(draft.amount)),
    ];
  }

  @override
  void dispose() {
    for (final amount in _amounts) {
      amount.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final next = <ParsedSpend>[];
    for (var index = 0; index < _drafts.length; index++) {
      final amount = parseMoney(_amounts[index].text.trim());
      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter each amount')));
        return;
      }
      next.add(_drafts[index].copyWith(amount: amount));
    }
    await widget.onSave(next);
  }

  Future<void> _pickCategory(int index) async {
    final draft = _drafts[index];
    final picked = await showModalBottomSheet<Category>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _CategoryPicker(categories: _categoriesFor(draft.kind), selectedId: draft.categoryId),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _drafts[index] = draft.copyWith(categoryId: picked.id, categoryName: picked.name, kind: picked.kind);
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _drafts.fold<int>(0, (sum, draft) => sum + draft.amount);
    final shop = _drafts.map((draft) => draft.merchant).whereType<String>().where((name) => name.isNotEmpty).firstOrNull;
    final details = _drafts.length == 1 ? _details(shop, _drafts.first.note) : null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.saving ? null : widget.onCancel,
                    icon: const Icon(LucideIcons.x),
                  ),
                  const Expanded(
                    child: Text(
                      'Check the bill',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: ColoredBox(
                      color: _field,
                      child: widget.imageBytes == null
                          ? const SizedBox(
                              height: 120,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.fileText, color: _muted, size: 32),
                                  SizedBox(height: 8),
                                  Text('PDF bill', style: TextStyle(color: _muted)),
                                ],
                              ),
                            )
                          : Image.memory(widget.imageBytes!, height: 180, width: double.infinity, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    shop ?? 'Purchase',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details ?? '${_drafts.length} ${_drafts.length == 1 ? 'item' : 'items'} · ${formatRupees(total)}',
                    style: const TextStyle(color: _muted, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  for (var index = 0; index < _drafts.length; index++) ...[
                    if (index > 0) const SizedBox(height: 10),
                    _ItemCard(
                      draft: _drafts[index],
                      title: details != null ? 'Total' : null,
                      amount: _amounts[index],
                      saving: widget.saving,
                      onCategory: () => _pickCategory(index),
                      onDate: () => _pickDate(index),
                      onRemove: _drafts.length < 2
                          ? null
                          : () => setState(() {
                              _amounts[index].dispose();
                              _amounts.removeAt(index);
                              _drafts.removeAt(index);
                            }),
                    ),
                  ],
                  if (widget.error != null) ...[
                    const SizedBox(height: 12),
                    Text(widget.error!, style: const TextStyle(color: Color(0xFFFF6B6B))),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: widget.saving || _drafts.isEmpty ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _lime,
                    foregroundColor: _ink,
                    disabledBackgroundColor: const Color(0xFF3A3A3C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  child: Text(widget.saving ? 'Saving' : (details != null ? 'Save' : 'Save ${_drafts.length == 1 ? 'item' : '${_drafts.length} items'}')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _details(String? shop, String note) {
    var text = note.trim();
    if (shop != null && text.toLowerCase().startsWith(shop.toLowerCase())) {
      text = text.substring(shop.length).replaceFirst(RegExp(r'^\s*[—-]\s*'), '').trim();
    }
    return text.isEmpty ? null : text;
  }

  ParsedSpend _matched(ParsedSpend draft) {
    final options = widget.categories.where((category) => category.kind == draft.kind);
    if (options.any((category) => category.id == draft.categoryId)) return draft;
    if (options.isEmpty) return draft;
    final fallback = options.first;
    return draft.copyWith(categoryId: fallback.id, categoryName: fallback.name);
  }

  List<Category> _categoriesFor(String kind) {
    final same = widget.categories.where((category) => category.kind == kind).toList();
    return same.isEmpty ? widget.categories : same;
  }

  Future<void> _pickDate(int index) async {
    final current = DateTime.tryParse(_drafts[index].occurredOn) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(DateTime.now()) ? DateTime.now() : current,
      firstDate: DateTime(current.year - 5),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _drafts[index] = _drafts[index].copyWith(occurredOn: isoDate(picked));
    });
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.draft,
    required this.title,
    required this.amount,
    required this.saving,
    required this.onCategory,
    required this.onDate,
    required this.onRemove,
  });

  final ParsedSpend draft;
  final String? title;
  final TextEditingController amount;
  final bool saving;
  final VoidCallback onCategory;
  final VoidCallback onDate;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final title = this.title ?? (draft.note.trim().isNotEmpty ? draft.note.trim() : (draft.merchant ?? 'Item'));
    final today = isoDate(DateTime.now());
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryIcon(name: draft.categoryName, kind: draft.kind, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: saving ? null : onRemove,
                  icon: const Icon(LucideIcons.x, color: _muted, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextField(
              controller: amount,
              enabled: !saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
              cursorColor: _lime,
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: _muted, fontSize: 22, fontWeight: FontWeight.w700),
                filled: true,
                fillColor: _field,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  label: draft.categoryName,
                  onTap: saving ? null : onCategory,
                  leading: CategoryIcon(name: draft.categoryName, kind: draft.kind, size: 22),
                ),
                _Chip(
                  label: draft.occurredOn == today ? 'Today' : formatDate(draft.occurredOn),
                  icon: LucideIcons.calendar,
                  onTap: saving ? null : onDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap, this.icon, this.leading});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _field,
      shape: const StadiumBorder(side: BorderSide(color: _line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(leading != null ? 6 : 10, 6, 12, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?leading,
              if (icon != null) Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.categories, required this.selectedId});

  final List<Category> categories;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text('Category', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          for (final category in categories)
            ListTile(
              leading: CategoryIcon(name: category.name, kind: category.kind, size: 36),
              title: Text(category.name, style: const TextStyle(color: Colors.white)),
              trailing: category.id == selectedId ? const Icon(LucideIcons.check, color: _lime) : null,
              onTap: () => Navigator.pop(context, category),
            ),
        ],
      ),
    );
  }
}

String _amountText(int paise) {
  if (paise % 100 == 0) return (paise ~/ 100).toString();
  return (paise / 100).toStringAsFixed(2);
}
