import 'dart:convert';

import 'package:finance_track/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityCache {
  ActivityCache({this._preferences});

  static const prefix = 'activity_tx_';

  SharedPreferences? _preferences;
  final Map<String, List<TransactionItem>> _memory = {};

  List<TransactionItem>? memory(String from, String to, {String? kind}) =>
      _memory[_key(from, to, kind)];

  void forget() {
    _memory.clear();
  }

  Future<List<TransactionItem>?> read(String from, String to, {String? kind}) async {
    final key = _key(from, to, kind);
    final cached = _memory[key];
    if (cached != null) return cached;
    try {
      final preferences = await _store();
      final raw = preferences.getString('$prefix$key');
      if (raw == null) return null;
      final items = _decode(raw);
      _memory[key] = items;
      return items;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    String from,
    String to,
    List<TransactionItem> items, {
    String? kind,
  }) async {
    final key = _key(from, to, kind);
    _memory[key] = items;
    try {
      final preferences = await _store();
      await preferences.setString(
        '$prefix$key',
        jsonEncode(items.map((item) => item.toJson()).toList()),
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

  List<TransactionItem> _decode(String raw) {
    final items = jsonDecode(raw) as List<dynamic>;
    return items
        .map((item) => TransactionItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
