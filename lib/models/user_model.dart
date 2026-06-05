class UserModel {
  final String id;
  final String? phoneNumber;
  final String? email;
  final String? name;
  final String role;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  UserModel({
    required this.id,
    this.phoneNumber,
    this.email,
    this.name,
    required this.role,
    required this.createdAt,
    this.lastLogin,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      name: json['name'],
      role: json['role'] ?? 'user',
      createdAt: DateTime.parse(json['createdAt']),
      lastLogin: json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'email': email,
      'name': name,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'isActive': isActive,
    };
  }
}