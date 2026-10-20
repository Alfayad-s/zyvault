import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoredTurn {
  const StoredTurn({
    required this.role,
    required this.content,
    this.proposal,
    this.review = 'open',
    this.voice = false,
    this.seconds = 0,
  });

  final String role;
  final String content;
  final Map<String, dynamic>? proposal;
  final String review;
  final bool voice;
  final int seconds;
}

/// The chat thread lives on the phone. Older turns are packed into a short
/// memory line so the model can recall them without resending the whole thread.
class ChatStore {
  static const _key = 'chat.turns';
  static const maxTurns = 60;

  static Future<List<StoredTurn>> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map && item['role'] is String && item['content'] is String)
            StoredTurn(
              role: item['role'] as String,
              content: item['content'] as String,
              proposal: item['proposal'] is Map ? Map<String, dynamic>.from(item['proposal'] as Map) : null,
              review: item['review'] is String ? item['review'] as String : 'open',
              voice: item['voice'] == true,
              seconds: item['seconds'] is num ? (item['seconds'] as num).toInt() : 0,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> write(List<StoredTurn> turns) async {
    final kept = turns.length > maxTurns ? turns.sublist(turns.length - maxTurns) : turns;
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode([
          for (final turn in kept)
            {
              'role': turn.role,
              'content': turn.content,
              'proposal': turn.proposal,
              'review': turn.review,
              'voice': turn.voice,
              'seconds': turn.seconds,
            },
        ]),
      );
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}

/// Older turns, newest first until the line is full, then flipped back into order.
String chatMemory(List<StoredTurn> turns, {int tail = 8, int maxChars = 700}) {
  if (turns.length <= tail) return '';
  final older = turns.sublist(0, turns.length - tail);
  final lines = <String>[];
  var used = 0;
  for (final turn in older.reversed) {
    final who = turn.role == 'user' ? 'User' : 'Assistant';
    final text = turn.content.replaceAll('\n', ' ').trim();
    if (text.isEmpty) continue;
    final clip = text.length > 90 ? '${text.substring(0, 90)}…' : text;
    final line = '$who: $clip';
    if (used + line.length + 1 > maxChars) break;
    lines.add(line);
    used += line.length + 1;
  }
  return lines.reversed.join('\n');
}
