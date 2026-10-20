import 'dart:async';
import 'dart:convert';

import 'package:finance_track/config/api_config.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:http/http.dart' as http;

class FinanceException implements Exception {
  FinanceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get unavailable => statusCode == null || statusCode == 503;

  @override
  String toString() => message;
}

class AuthExpiredException extends FinanceException {
  AuthExpiredException() : super('Sign in again', statusCode: 401);
}

class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String baseUrl;

  Future<CodeRequest> sendCode(String email) async {
    final body = await _post('/auth/email/code', {
      'email': email,
    }) as Map<String, dynamic>;
    return CodeRequest(
      codeLength: (body['codeLength'] as num?)?.toInt() ?? 6,
      resendAfterSeconds: (body['resendAfterSeconds'] as num?)?.toInt() ?? 30,
    );
  }

  Future<AuthTokens> verifyCode(String email, String code) async {
    final body = await _post('/auth/email/verify', {
      'email': email,
      'code': code,
    });
    return AuthTokens.fromJson(body as Map<String, dynamic>);
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final body = await _post('/auth/refresh', {'refreshToken': refreshToken});
    return AuthTokens.fromJson(body as Map<String, dynamic>);
  }

  Future<Object?> _post(String path, Map<String, dynamic> payload) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401) {
        throw FinanceException(
          _message(_tryJson(response.body), 401),
          statusCode: 401,
        );
      }
      return _decode(response);
    } on TimeoutException {
      throw FinanceException('The server took too long, try again');
    } on http.ClientException {
      throw FinanceException('Could not reach the server');
    }
  }
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final expires = (json['expiresAt'] as num?)?.toInt();
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: expires == null
          ? DateTime.now().add(const Duration(minutes: 55))
          : DateTime.fromMillisecondsSinceEpoch(expires * 1000),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}

class CodeRequest {
  const CodeRequest({
    required this.codeLength,
    required this.resendAfterSeconds,
  });

  final int codeLength;
  final int resendAfterSeconds;
}

Object? _tryJson(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

class ServerCheck {
  const ServerCheck({required this.name, required this.ok, required this.detail});

  final String name;
  final bool ok;
  final String detail;

  factory ServerCheck.fromJson(Map<String, dynamic> json) => ServerCheck(
    name: json['name'] as String? ?? '',
    ok: json['ok'] == true,
    detail: json['detail'] as String? ?? '',
  );
}

class ServerReport {
  const ServerReport({required this.ok, required this.checks});

  final bool ok;
  final List<ServerCheck> checks;

  factory ServerReport.fromJson(Map<String, dynamic> json) {
    final checks = json['checks'];
    return ServerReport(
      ok: json['status'] == 'ok',
      checks: checks is List
          ? [
              for (final item in checks)
                if (item is Map<String, dynamic>) ServerCheck.fromJson(item),
            ]
          : const [],
    );
  }
}

class ChatAnswer {
  const ChatAnswer({required this.reply, this.proposal});

  final String reply;
  final Map<String, dynamic>? proposal;
}

class FinanceApi {
  FinanceApi({
    this._token,
    this.tokenProvider,
    this.onTokenRejected,
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String? _token;
  final Future<String?> Function()? tokenProvider;
  final Future<String?> Function()? onTokenRejected;
  final http.Client _client;
  final String baseUrl;

  Future<ServerReport> serverStatus() async {
    final body = await _send('GET', '/health/details', timeout: const Duration(seconds: 20));
    return ServerReport.fromJson(body as Map<String, dynamic>);
  }

  Future<Summary> summary(String month) async {
    final body = await _send('GET', '/summary?month=$month');
    return Summary.fromJson(body as Map<String, dynamic>);
  }

  Future<List<Account>> accounts() async {
    final body = await _send('GET', '/accounts');
    return _list(body, Account.fromJson);
  }

  Future<Account> createAccount({
    required String name,
    required String type,
    required int openingBalance,
    String? bankId,
  }) async {
    final body = await _send(
      'POST',
      '/accounts',
      body: {
        'name': name,
        'type': type,
        'openingBalance': openingBalance,
        'bankId': ?bankId,
      },
    );
    return Account.fromJson(body as Map<String, dynamic>);
  }

  Future<Account> updateAccount({
    required String id,
    required String name,
    required String type,
    required int openingBalance,
    String? bankId,
  }) async {
    final body = await _send(
      'PATCH',
      '/accounts/$id',
      body: {
        'name': name,
        'type': type,
        'openingBalance': openingBalance,
        'bankId': ?bankId,
      },
    );
    return Account.fromJson(body as Map<String, dynamic>);
  }

  Future<void> deleteAccount(String id) async {
    await _send('DELETE', '/accounts/$id');
  }

  Future<List<Bank>> banks() async {
    final body = await _send('GET', '/banks');
    return _list(body, Bank.fromJson);
  }

  Future<List<Category>> categories() async {
    final body = await _send('GET', '/categories');
    return _list(body, Category.fromJson);
  }

  Future<List<CategoryIconOption>> categoryIcons() async {
    final body = await _send('GET', '/categories/icons');
    return _list(body, CategoryIconOption.fromJson);
  }

  Future<Category> createCategory({
    required String name,
    required String kind,
    required String icon,
  }) async {
    final body = await _send(
      'POST',
      '/categories',
      body: {'name': name, 'kind': kind, 'icon': icon},
    );
    return Category.fromJson(body as Map<String, dynamic>);
  }

  Future<Category> updateCategory({
    required String id,
    String? name,
    String? icon,
  }) async {
    final body = await _send(
      'PATCH',
      '/categories/$id',
      body: {'name': ?name, 'icon': ?icon},
    );
    return Category.fromJson(body as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) async {
    await _send('DELETE', '/categories/$id');
  }

  Future<ChatAnswer> chat({
    required String today,
    required List<Map<String, String>> messages,
    String memory = '',
  }) async {
    final tail = [
      for (final message in (messages.length > 8 ? messages.sublist(messages.length - 8) : messages))
        {
          'role': message['role'] ?? 'user',
          'content': (message['content'] ?? '').length > 400
              ? (message['content'] ?? '').substring(0, 400)
              : (message['content'] ?? ''),
        },
    ];
    final remembered = memory.length > 800 ? memory.substring(0, 800) : memory;
    final Object? body;
    try {
      body = await _send(
        'POST',
        '/chat',
        body: {
          'today': today,
          'messages': tail,
          if (remembered.isNotEmpty) 'memory': remembered,
        },
        timeout: const Duration(seconds: 20),
      );
    } on TimeoutException {
      throw FinanceException('The chatbot did not answer in time');
    } on http.ClientException catch (caught) {
      throw FinanceException(caught.message);
    }
    final map = body as Map<String, dynamic>?;
    final reply = map?['reply'];
    if (reply is! String || reply.isEmpty) {
      throw FinanceException('The chatbot returned an empty reply');
    }
    final proposal = map?['proposal'];
    return ChatAnswer(
      reply: reply,
      proposal: proposal is Map<String, dynamic> ? proposal : null,
    );
  }

  Future<void> applyChat(Map<String, dynamic> action) async {
    await _send('POST', '/chat/apply', body: {'action': action});
  }

  Future<AskAnswer> ask({
    required String question,
    required String today,
  }) async {
    final Object? body;
    try {
      body = await _send(
        'POST',
        '/ask',
        body: {'question': question, 'today': today},
        timeout: const Duration(seconds: 60),
      );
    } on TimeoutException {
      throw FinanceException('The AI took too long, try again');
    } on http.ClientException catch (caught) {
      throw FinanceException(caught.message);
    }
    return AskAnswer.fromJson(body as Map<String, dynamic>);
  }

  /// Registers this phone for push. Returns whether the server can send pushes.
  Future<bool> registerDevice({
    required String token,
    required String platform,
    required int utcOffsetMinutes,
  }) async {
    final body = await _send(
      'POST',
      '/devices',
      body: {
        'token': token,
        'platform': platform,
        'utcOffsetMinutes': utcOffsetMinutes,
      },
    );
    return (body as Map<String, dynamic>?)?['push'] == true;
  }

  Future<void> unregisterDevice(String token) async {
    await _send('DELETE', '/devices', body: {'token': token});
  }

  Future<List<Goal>> goals() async {
    final body = await _send('GET', '/goals');
    return _list(body, Goal.fromJson);
  }

  Future<Goal> saveGoal({
    String? id,
    required String name,
    required String icon,
    required int targetAmount,
    String? targetDate,
  }) async {
    final body = await _send(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/goals' : '/goals/$id',
      body: {
        'name': name,
        'icon': icon,
        'targetAmount': targetAmount,
        'targetDate': targetDate,
      },
    );
    return Goal.fromJson(body as Map<String, dynamic>);
  }

  Future<void> deleteGoal(String id) async {
    await _send('DELETE', '/goals/$id');
  }

  Future<List<GoalEntry>> goalEntries(String goalId) async {
    final body = await _send('GET', '/goals/$goalId/entries');
    return _list(body, GoalEntry.fromJson);
  }

  Future<Goal> addGoalEntry({
    required String goalId,
    required String type,
    required int amount,
    required String occurredOn,
    String? note,
  }) async {
    final body = await _send(
      'POST',
      '/goals/$goalId/entries',
      body: {
        'type': type,
        'amount': amount,
        'occurredOn': occurredOn,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return Goal.fromJson(
      (body as Map<String, dynamic>)['goal'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteGoalEntry(String entryId) async {
    await _send('DELETE', '/goals/entries/$entryId');
  }

  Future<Debts> debts() async {
    final body = await _send('GET', '/debts');
    return Debts.fromJson(body as Map<String, dynamic>);
  }

  Future<DebtEntry> createDebt({
    required String person,
    required String type,
    required int amount,
    required String occurredOn,
    String? accountId,
    String? note,
  }) async {
    final body = await _send(
      'POST',
      '/debts',
      body: {
        'person': person,
        'type': type,
        'amount': amount,
        'occurredOn': occurredOn,
        'accountId': ?accountId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return DebtEntry.fromJson(body as Map<String, dynamic>);
  }

  Future<void> deleteDebt(String id) async {
    await _send('DELETE', '/debts/$id');
  }

  Future<List<Budget>> budgets(String month) async {
    final body = await _send('GET', '/budgets?month=$month');
    return _list(body, Budget.fromJson);
  }

  Future<Budget> saveBudget({
    required String categoryId,
    required String month,
    required int limitAmount,
  }) async {
    final body = await _send(
      'PUT',
      '/budgets',
      body: {
        'categoryId': categoryId,
        'month': month,
        'limitAmount': limitAmount,
      },
    );
    return Budget.fromJson(body as Map<String, dynamic>);
  }

  Future<void> deleteBudget(String id) async {
    await _send('DELETE', '/budgets/$id');
  }

  Future<List<TransactionItem>> transactions({
    String? month,
    String? from,
    String? to,
    int? limit,
  }) async {
    final params = <String>[
      if (month != null) 'month=$month',
      if (from != null) 'from=$from',
      if (to != null) 'to=$to',
      if (limit != null) 'limit=$limit',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final body = await _send('GET', '/transactions$query');
    return _list(body, TransactionItem.fromJson);
  }

  Future<TransactionItem> saveTransaction({
    String? id,
    required String accountId,
    required String categoryId,
    required int amount,
    required String kind,
    required String occurredOn,
    String? note,
  }) async {
    final body = await _send(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/transactions' : '/transactions/$id',
      body: {
        'accountId': accountId,
        'categoryId': categoryId,
        'amount': amount,
        'kind': kind,
        'occurredOn': occurredOn,
        'note': note,
      },
    );
    return TransactionItem.fromJson(body as Map<String, dynamic>);
  }

  Future<void> deleteTransaction(String id) async {
    await _send('DELETE', '/transactions/$id');
  }

  Future<List<ParsedSpend>> previewBill({
    required String imageBase64,
    required String mimeType,
    required String accountId,
    required String today,
    String? text,
  }) async {
    final Object? body;
    try {
      body = await _send(
        'POST',
        '/transactions/parse',
        body: {
          if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
          'accountId': accountId,
          'today': today,
          'time': clockTime(DateTime.now()),
          'image': imageBase64,
          'mimeType': mimeType,
          'preview': true,
        },
        timeout: const Duration(seconds: 75),
      );
    } on TimeoutException {
      throw FinanceException('The AI parser took too long');
    } on http.ClientException catch (caught) {
      throw FinanceException(caught.message);
    }
    final items = body as List<dynamic>? ?? [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic> &&
            item['parsed'] is Map<String, dynamic>)
          ParsedSpend.fromJson(item['parsed'] as Map<String, dynamic>),
    ];
  }

  Future<List<ParsedSpend>> previewText({
    required String text,
    required String accountId,
    required String today,
  }) async {
    final Object? body;
    try {
      body = await _send(
        'POST',
        '/transactions/parse',
        body: {
          'text': text,
          'accountId': accountId,
          'today': today,
          'time': clockTime(DateTime.now()),
          'preview': true,
        },
        timeout: const Duration(seconds: 75),
      );
    } on TimeoutException {
      throw FinanceException('The AI parser took too long');
    } on http.ClientException catch (caught) {
      throw FinanceException(caught.message);
    }
    final items = body as List<dynamic>? ?? [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic> &&
            item['parsed'] is Map<String, dynamic>)
          ParsedSpend.fromJson(item['parsed'] as Map<String, dynamic>),
    ];
  }

  Future<List<Schedule>> schedules() async {
    final body = await _send('GET', '/schedules');
    return _list(body, Schedule.fromJson);
  }

  Future<void> deleteSchedule(String id) async {
    await _send('DELETE', '/schedules/$id');
  }

  Future<int> runSchedules(String today) async {
    final body = await _send(
      'POST',
      '/schedules/run',
      body: {'today': today, 'time': clockTime(DateTime.now())},
    );
    return ((body as Map<String, dynamic>?)?['posted'] as num?)?.toInt() ?? 0;
  }

  Future<List<AgentResult>> commitTransactions({
    required List<ParsedSpend> items,
    required String accountId,
    required String today,
  }) async {
    final body = await _send(
      'POST',
      '/transactions/commit',
      body: {
        'items': [for (final item in items) item.toCommitJson()],
        'accountId': accountId,
        'today': today,
        'time': clockTime(DateTime.now()),
      },
      timeout: const Duration(seconds: 30),
    );
    final results = body as List<dynamic>? ?? [];
    return [
      for (final item in results)
        if (item is Map<String, dynamic>) AgentResult.fromJson(item),
    ];
  }

  Future<List<AgentResult>> parseTransactions({
    required String text,
    required String accountId,
    required String today,
  }) async {
    final Object? body;
    try {
      body = await _send(
        'POST',
        '/transactions/parse',
        body: {
          'text': text,
          'accountId': accountId,
          'today': today,
          'time': clockTime(DateTime.now()),
        },
        timeout: const Duration(seconds: 75),
      );
    } on TimeoutException {
      throw FinanceException('The AI parser took too long');
    } on http.ClientException catch (caught) {
      throw FinanceException(caught.message);
    }
    final items = body as List<dynamic>? ?? [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) AgentResult.fromJson(item),
    ];
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final token = await tokenProvider?.call() ?? _token;
      if (token == null) throw AuthExpiredException();
      var response = await _request(method, path, token, body, timeout);
      if (response.statusCode == 401 && onTokenRejected != null) {
        final renewed = await onTokenRejected!();
        if (renewed == null) throw AuthExpiredException();
        response = await _request(method, path, renewed, body, timeout);
      }
      return _decode(response);
    } on AuthExpiredException {
      rethrow;
    } on FinanceException {
      rethrow;
    } on TimeoutException {
      throw FinanceException(
        'Could not reach the server. Start the API, then try again.',
      );
    } on http.ClientException {
      throw FinanceException('Could not reach the server');
    }
  }

  Future<http.Response> _request(
    String method,
    String path,
    String token,
    Map<String, dynamic>? body,
    Duration timeout,
  ) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final streamed = await _client.send(request).timeout(timeout);
    return http.Response.fromStream(streamed);
  }
}

List<T> _list<T>(Object? body, T Function(Map<String, dynamic>) parse) {
  final items = body as List<dynamic>? ?? [];
  return items.map((item) => parse(item as Map<String, dynamic>)).toList();
}

Object? _decode(http.Response response) {
  if (response.statusCode == 401) {
    throw AuthExpiredException();
  }
  if (response.statusCode == 204) {
    return null;
  }
  Object? body;
  if (response.body.isNotEmpty) {
    body = jsonDecode(response.body);
  }
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return body;
  }
  throw FinanceException(
    _message(body, response.statusCode),
    statusCode: response.statusCode,
  );
}

String _message(Object? body, int statusCode) {
  if (body is Map<String, dynamic>) {
    final message = body['message'];
    if (message is List) {
      return message.join('\n');
    }
    if (message is String && message.isNotEmpty) {
      if (message.contains('schema cache')) {
        return 'The finance tables are not in Supabase yet. Run apps/api/supabase/schema.sql in the Supabase SQL editor, then refresh.';
      }
      return message;
    }
  }
  return 'Request failed ($statusCode)';
}
