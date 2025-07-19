class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime registrationDate;
  final bool isBlocked;
  final DateTime? lastSignIn;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.registrationDate,
    this.isBlocked = false,
    this.lastSignIn,
  });
} 