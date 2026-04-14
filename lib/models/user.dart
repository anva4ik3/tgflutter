// lib/models/user.dart
class User {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isVerified;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.isVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        email: j['email'] ?? '',
        username: j['username'],
        displayName: j['display_name'] ?? j['username'],
        avatarUrl: j['avatar_url'],
        bio: j['bio'],
        isVerified: j['is_verified'] ?? false,
      );
}
