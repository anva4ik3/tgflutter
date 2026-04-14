class User {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final bool isVerified;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.bio,
    this.isOnline = false,
    this.lastSeenAt,
    this.isVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'],
    username: j['username'],
    displayName: j['display_name'] ?? j['username'],
    email: j['email'],
    avatarUrl: j['avatar_url'],
    bio: j['bio'],
    isOnline: j['is_online'] ?? false,
    lastSeenAt: j['last_seen_at'] != null ? DateTime.tryParse(j['last_seen_at']) : null,
    isVerified: j['is_verified'] ?? false,
  );

  User copyWith({bool? isOnline, DateTime? lastSeenAt}) => User(
    id: id, username: username, displayName: displayName,
    email: email, avatarUrl: avatarUrl, bio: bio, isVerified: isVerified,
    isOnline: isOnline ?? this.isOnline,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
}
