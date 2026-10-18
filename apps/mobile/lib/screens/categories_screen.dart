import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _red = Color(0xFFFF6B6B);

const _hiddenIcons = {'lent', 'borrowed'};

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.ledger});

  final Ledger ledger;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  var _kind = 'expense';

  @override
  void initState() {
    super.initState();
    widget.ledger.loadCategoryIcons();
  }

  Future<void> _open({Category? existing}) async {
    final ledger = widget.ledger;
    final icons = await ledger.loadCategoryIcons();
    if (!mounted) return;
    final result = await showModalBottomSheet<_CategoryDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _CategorySheet(
        icons: [
          for (final icon in icons)
            if (!_hiddenIcons.contains(icon.key)) icon.key,
        ],
        kind: existing?.kind ?? _kind,
        existing: existing,
      ),
    );
    if (result == null || !mounted) return;
    try {
      if (result.delete && existing != null) {
        if (!await _confirmDelete(existing)) return;
        await ledger.deleteCategory(existing.id);
      } else if (existing != null) {
        await ledger.updateCategory(
          id: existing.id,
          name: result.name,
          icon: result.icon,
        );
      } else {
        await ledger.createCategory(
          name: result.name,
          kind: result.kind,
          icon: result.icon,
        );
        if (mounted) setState(() => _kind = result.kind);
      }
    } on FinanceException catch (caught) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(caught.message)));
      }
    }
  }

  Future<bool> _confirmDelete(Category category) async {
    final fallback = category.kind == 'income' ? 'Other income' : 'Other';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text('Delete ${category.name}?'),
        content: Text(
          'Anything saved in ${category.name} moves to $fallback. Its budget is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ListenableBuilder(
        listenable: widget.ledger,
        builder: (context, _) {
          final categories =
              widget.ledger.categories
                  .where((category) => category.kind == _kind)
                  .toList()
                ..sort((a, b) {
                  if (a.custom != b.custom) return a.custom ? -1 : 1;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _KindSwitch(
                kind: _kind,
                onChanged: (kind) => setState(() => _kind = kind),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap one of yours to rename, change its icon, or delete it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 112,
                ),
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _NewTile(onTap: () => _open());
                  final category = categories[index - 1];
                  return _CategoryTile(
                    category: category,
                    onTap: category.custom
                        ? () => _open(existing: category)
                        : null,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.kind, required this.onChanged});

  final String kind;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (final item in const [
            ('expense', 'Expense'),
            ('income', 'Income'),
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kind == item.$1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      color: kind == item.$1 ? Colors.black : _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NewTile extends StatelessWidget {
  const _NewTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _lime, width: 1.5),
              ),
              child: const Icon(LucideIcons.plus, color: _lime),
            ),
            const SizedBox(height: 8),
            const Text(
              'New',
              style: TextStyle(color: _lime, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, this.onTap});

  final Category category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CategoryIcon(
                      name: category.name,
                      kind: category.kind,
                      size: 52,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (category.custom)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(LucideIcons.pencil, color: _muted, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDraft {
  const _CategoryDraft({
    required this.name,
    required this.kind,
    required this.icon,
  }) : delete = false;

  const _CategoryDraft.delete()
    : name = '',
      kind = '',
      icon = '',
      delete = true;

  final String name;
  final String kind;
  final String icon;
  final bool delete;
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.icons,
    required this.kind,
    this.existing,
  });

  final List<String> icons;
  final String kind;
  final Category? existing;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late var _kind = widget.kind;
  late String? _icon =
      widget.existing?.icon ??
      (widget.icons.isEmpty
          ? null
          : widget.icons.contains(_kind == 'income' ? 'other-income' : 'other')
          ? (_kind == 'income' ? 'other-income' : 'other')
          : widget.icons.first);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }
    final icon = _icon;
    if (icon == null) {
      setState(() => _error = 'Pick an icon');
      return;
    }
    Navigator.of(context)
        .pop(_CategoryDraft(name: name, kind: _kind, icon: icon));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_icon != null) CategoryIcon.key(_icon!, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    editing ? 'Edit category' : 'New category',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!editing) ...[
              _KindSwitch(
                kind: _kind,
                onChanged: (kind) => setState(() => _kind = kind),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _name,
              autofocus: !editing,
              maxLength: 32,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: _kind == 'income'
                    ? 'e.g. Tuition I teach'
                    : 'e.g. Gym, Maid, Cigarettes',
                hintStyle: const TextStyle(color: Color(0xFF5C5C60)),
                counterStyle: const TextStyle(color: _muted),
                filled: true,
                fillColor: _field,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Icon',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (widget.icons.isEmpty)
              const Text(
                'Icons could not load. Check your connection.',
                style: TextStyle(color: _muted),
              )
            else
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final icon in widget.icons)
                    Semantics(
                      button: true,
                      selected: icon == _icon,
                      label: icon,
                      child: GestureDetector(
                        onTap: () => setState(() => _icon = icon),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: icon == _icon ? _lime : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: FittedBox(child: CategoryIcon.key(icon)),
                        ),
                      ),
                    ),
                ],
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _red),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(editing ? 'Save changes' : 'Add category'),
              ),
            ),
            if (editing)
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(const _CategoryDraft.delete()),
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text('Delete category'),
                style: TextButton.styleFrom(foregroundColor: _red),
              ),
          ],
        ),
      ),
    );
  }
}
