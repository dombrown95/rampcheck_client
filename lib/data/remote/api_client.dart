import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_client_contract.dart';

class WarehouseApiClient implements ApiClient {
  WarehouseApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  static const apiKey = 'api_warehouse_student_key_1234567890abcdef';

  Map<String, String> _jsonHeaders() => const {
        'Content-Type': 'application/json',
      };

  Map<String, String> _authHeaders() => {
        ..._jsonHeaders(),
        'X-API-Key': apiKey,
      };

  Map<String, dynamic> _decodeOrThrow(http.Response res, {required String context}) {
    Map<String, dynamic> body;

    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is Map) {
        body = decoded.cast<String, dynamic>();
      } else {
        throw ApiException('Expected JSON object but got: $decoded');
      }
    } catch (e) {
      throw ApiException('API error in $context: HTTP ${res.statusCode} - ${res.body}');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = body['error'] ?? body['message'] ?? res.body;
      throw ApiException('API error in $context: HTTP ${res.statusCode} - $msg');
    }

    return body;
  }

  @override
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String role,
  }) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/api/v1/users'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'username': username,
            'password': password,
            'role': role,
          }),
        )
        .timeout(const Duration(seconds: 10));

    return _decodeOrThrow(res, context: 'createUser');
  }

  @override
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/api/v1/users/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));

    return _decodeOrThrow(res, context: 'login');
  }

  @override
  Future<Map<String, dynamic>> createLog({
    required String title,
    required String description,
    required String priority,
    required String status,
    required int userId,
  }) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/api/v1/logs'),
          headers: _authHeaders(),
          body: jsonEncode({
            'title': title,
            'description': description,
            'priority': priority,
            'status': status,
            'user_id': userId,
          }),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeOrThrow(res, context: 'createLog');
  }

  void dispose() => _http.close();
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
