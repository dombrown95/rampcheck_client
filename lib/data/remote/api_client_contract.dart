abstract class ApiClient {
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String role,
  });

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  });

  Future<Map<String, dynamic>> createLog({
    required String title,
    required String description,
    required String priority,
    required String status,
    required int userId,
  });
}