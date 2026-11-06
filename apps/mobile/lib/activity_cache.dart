import 'dart:convert';

import 'package:finance_track/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityPage {
  const ActivityPage({required this.items, required this.totals});

  final List<TransactionItem> items;
  final List<CategoryTotal> totals;
}

class ActivityCache {
  ActivityCache({this._preferences});

  static const prefix = 'activity_tx_';

  SharedPreferences? _preferences;
  final Map<String, ActivityPage> _memory = {};

  ActivityPage? memory(String from, String to, {String? kind}) =>
      _memory[_key(from, to, kind)];

  void forget() {
    _memory.clear();
  }

  Future<ActivityPage?> read(String from, String to, {String? kind}) async {
    final key = _key(from, to, kind);
    final cached = _memory[key];
    if (cached != null) return cached;
    try {
      final preferences = await _store();
      final raw = preferences.getString('$prefix$key');
      if (raw == null) return null;
      final page = _decode(raw);
      _memory[key] = page;
      return page;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    String from,
    String to,
    List<TransactionItem> items,
    List<CategoryTotal> totals, {
    String? kind,
  }) async {
    final key = _key(from, to, kind);
    final page = ActivityPage(items: items, totals: totals);
    _memory[key] = page;
    try {
      final preferences = await _store();
      await preferences.setString(
        '$prefix$key',
        jsonEncode({
          'items': items.map((item) => item.toJson()).toList(),
          'totals': totals.map((item) => item.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final keys = preferences.getKeys().where((key) => key.startsWith(prefix));
      for (final key in keys) {
        await preferences.remove(key);
      }
    } catch (_) {}
  }

  Future<SharedPreferences> _store() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  String _key(String from, String to, [String? kind]) =>
      kind == null ? '$from:$to' : '$from:$to:$kind';

  ActivityPage _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return ActivityPage(items: _items(decoded), totals: const []);
    }
    final map = decoded as Map<String, dynamic>;
    return ActivityPage(
      items: _items(map['items']),
      totals: [
        for (final item in map['totals'] as List<dynamic>? ?? [])
          if (item is Map<String, dynamic>) CategoryTotal.fromJson(item),
      ],
    );
  }

  List<TransactionItem> _items(Object? raw) {
    if (raw is! List) return [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) TransactionItem.fromJson(item),
    ];
  }
}
