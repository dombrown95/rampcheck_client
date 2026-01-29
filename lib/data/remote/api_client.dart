import 'dart:convert';
import 'package:http/http.dart' as http;

class WarehouseApi {
  WarehouseApi({required this.baseUrl});

  final String baseUrl;

  static const apiKey = 'api_warehouse_student_key_1234567890abcdef';

  Map<String, String> _jsonHeaders() => {
        'Content-Type': 'application/json',
      };

  Map<String, String> _authHeaders() => {
        ..._jsonHeaders(),
        'X-API-Key': apiKey,
      };

  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/users'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'username': username,
        'password': password,
        'role': role,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/users/login'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLog({
    required String title,
    required String description,
    required String priority,
    required String status,
    required int userId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/logs'),
      headers: _authHeaders(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'priority': priority,
        'status': status,
        'user_id': userId,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}