enum UserRole { guest, owner }

class AppUser {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final UserRole role;

  AppUser({
    required this.id,
    this.name,
    this.email,
    this.phone,
    required this.role,
  });
}
