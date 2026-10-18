import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      for (final draft in _drafts)
        TextEditingController(text: _amountText(draft.amount)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the amount payable')),
        );
        return;
      }
      next.add(_drafts[index].copyWith(amount: amount));
    }
    await widget.onSave(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.saving ? null : widget.onCancel,
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Text(
                      'Check the bill',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: widget.imageBytes == null
                        ? Container(
                            height: 140,
                            width: double.infinity,
                            color: const Color(0xFF1C1C1E),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf_outlined, size: 40),
                                SizedBox(height: 8),
                                Text('PDF bill'),
                              ],
                            ),
                          )
                        : Image.memory(
                            widget.imageBytes!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This is the amount payable. Change it if the read is wrong.',
                    style: TextStyle(color: Color(0xFF8E8E93), height: 1.3),
                  ),
                  for (var index = 0; index < _drafts.length; index++) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _amounts[index],
                      enabled: !widget.saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        labelText: _drafts[index].merchant ?? 'Amount payable',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryValue(_drafts[index]),
                      items: [
                        for (final category in _categoriesFor(
                          _drafts[index].kind,
                        ))
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: widget.saving
                          ? null
                          : (id) {
                              final category = widget.categories
                                  .cast<Category?>()
                                  .firstWhere(
                                    (item) => item?.id == id,
                                    orElse: () => null,
                                  );
                              if (category == null) return;
                              setState(() {
                                _drafts[index] = _drafts[index].copyWith(
                                  categoryId: category.id,
                                  categoryName: category.name,
                                  kind: category.kind,
                                );
                              });
                            },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatDate(_drafts[index].occurredOn)),
                      subtitle: Text(_drafts[index].note),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: widget.saving ? null : () => _pickDate(index),
                    ),
                  ],
                  if (widget.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.error!,
                      style: const TextStyle(color: Color(0xFFFF6B6B)),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: widget.saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC8F57A),
                    foregroundColor: const Color(0xFF17310C),
                  ),
                  child: Text(widget.saving ? 'Saving' : 'Save'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ParsedSpend _matched(ParsedSpend draft) {
    final options = widget.categories.where(
      (category) => category.kind == draft.kind,
    );
    if (options.any((category) => category.id == draft.categoryId)) {
      return draft;
    }
    if (options.isEmpty) return draft;
    final fallback = options.first;
    return draft.copyWith(categoryId: fallback.id, categoryName: fallback.name);
  }

  List<Category> _categoriesFor(String kind) {
    final same = widget.categories
        .where((category) => category.kind == kind)
        .toList();
    return same.isEmpty ? widget.categories : same;
  }

  String? _categoryValue(ParsedSpend draft) {
    final options = _categoriesFor(draft.kind);
    for (final category in options) {
      if (category.id == draft.categoryId) return category.id;
    }
    return options.isEmpty ? null : options.first.id;
  }

  Future<void> _pickDate(int index) async {
    final current =
        DateTime.tryParse(_drafts[index].occurredOn) ?? DateTime.now();
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

String _amountText(int paise) {
  if (paise % 100 == 0) return (paise ~/ 100).toString();
  return (paise / 100).toStringAsFixed(2);
}
