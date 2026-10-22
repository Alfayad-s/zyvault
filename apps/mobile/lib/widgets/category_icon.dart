import 'package:finance_track/models.dart';
import 'package:finance_track/widgets/operations_card.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.name,
    required this.kind,
    this.size = 42,
  }) : iconKey = null;

  const CategoryIcon.key(this.iconKey, {super.key, this.size = 42})
    : name = '',
      kind = 'expense';

  final String name;
  final String kind;
  final String? iconKey;
  final double size;

  static final _byCategory = <String, String>{};
  static final _byKey = <String, String>{};

  static void remember(List<Category> categories) {
    for (final category in categories) {
      final url = category.iconUrl;
      if (url == null) continue;
      _byCategory['${category.kind}:${category.name.toLowerCase()}'] = url;
      if (category.icon != null) _byKey[category.icon!] = url;
    }
  }

  static void rememberIcons(List<CategoryIconOption> icons) {
    for (final icon in icons) {
      if (icon.url != null) _byKey[icon.key] = icon.url!;
    }
  }

  static String? urlFor(String name, String kind) =>
      _byCategory['$kind:${name.toLowerCase()}'];

  static String? urlForKey(String key) => _byKey[key];

  @override
  Widget build(BuildContext context) {
    final key = iconKey;
    final url = key != null ? urlForKey(key) : urlFor(name, kind);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF5C5C60)),
      ),
      child: Icon(
        key != null ? _keyIcon(key) : categoryIcon(name, kind),
        color: Colors.white,
        size: size * 0.43,
      ),
    );
    if (url == null) return fallback;
    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: name.isEmpty ? key : name,
        frameBuilder: (context, child, frame, synchronous) {
          if (synchronous || frame != null) return child;
          return Stack(alignment: Alignment.center, children: [fallback, Opacity(opacity: 0, child: child)]);
        },
        errorBuilder: (context, error, stackTrace) =>
            OverflowBox(maxWidth: size, maxHeight: size, child: fallback),
      ),
    );
  }
}

IconData _keyIcon(String key) => switch (key) {
  'lent' => LucideIcons.handCoins,
  'borrowed' => LucideIcons.handHeart,
  _ => LucideIcons.sparkles,
};
