import 'dart:convert';

import 'package:finance_track/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityCache {
  ActivityCache({this._preferences});

  static const prefix = 'activity_tx_';

  SharedPreferences? _preferences;
  final Map<String, List<TransactionItem>> _memory = {};

  List<TransactionItem>? memory(String from, String to) =>
      _memory[_key(from, to)];

  Future<List<TransactionItem>?> read(String from, String to) async {
    final key = _key(from, to);
    final cached = _memory[key];
    if (cached != null) return cached;
    final preferences = await _store();
    final raw = preferences.getString('$prefix$key');
    if (raw == null) return null;
    final items = _decode(raw);
    _memory[key] = items;
    return items;
  }

  Future<void> write(
    String from,
    String to,
    List<TransactionItem> items,
  ) async {
    final key = _key(from, to);
    _memory[key] = items;
    final preferences = await _store();
    await preferences.setString(
      '$prefix$key',
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences.getKeys().where((key) => key.startsWith(prefix));
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  Future<SharedPreferences> _store() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  String _key(String from, String to) => '$from:$to';

  List<TransactionItem> _decode(String raw) {
    final items = jsonDecode(raw) as List<dynamic>;
    return items
        .map((item) => TransactionItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
