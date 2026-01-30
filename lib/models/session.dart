class Session {
  final String username;
  final String password;
  final String role;

  const Session({
    required this.username,
    required this.password,
    required this.role,
  });

  Map<String, Object?> toJson() => {
        'username': username,
        'password': password,
        'role': role,
      };

  factory Session.fromJson(Map<String, Object?> json) {
    return Session(
      username: (json['username'] as String?) ?? '',
      password: (json['password'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'manager',
    );
  }
}