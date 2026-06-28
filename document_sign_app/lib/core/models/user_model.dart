class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? position;
  final String? department;
  final bool mustChangePassword;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.position,
    this.department,
    this.mustChangePassword = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['fullName'],
      role: json['role'],
      position: json['position'],
      department: json['department'],
      mustChangePassword: json['mustChangePassword'] ?? false,
    );
  }

  bool get isAdmin => role == 'admin';
}
