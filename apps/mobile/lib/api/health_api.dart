import 'dart:convert';

import 'package:finance_track/config/api_config.dart';
import 'package:http/http.dart' as http;

class HealthApi {
  HealthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;

  Future<String> fetchStatus() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw HealthException('Health check failed (${response.statusCode})');
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['status'] is! String) {
        throw HealthException('Health check returned an unexpected response');
      }
      return body['status'] as String;
    } on HealthException {
      rethrow;
    } catch (_) {
      throw HealthException('Health check unavailable');
    } finally {
      if (_ownsClient) {
        _client.close();
      }
    }
  }
}

class HealthException implements Exception {
  HealthException(this.message);

  final String message;

  @override
  String toString() => message;
}
