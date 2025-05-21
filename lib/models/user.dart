class User {
  final int userId;
  final String name;
  final String userType;

  User({required this.userId, required this.name, required this.userType});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      name: json['name'],
      userType: json['user_type'],
    );
  }
}