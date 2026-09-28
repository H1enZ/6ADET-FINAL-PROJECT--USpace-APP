/// One person. Mirrors a row in the `profiles` table, plus [avatarUrl],
/// a short-lived link to their photo (worked out by ProfileService).
class Profile {
  const Profile({
    required this.userId,
    required this.displayName,
    this.coupleId,
    this.birthday,
    this.avatarPath,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;

  /// Null until the person starts or joins a couple.
  final String? coupleId;

  final DateTime? birthday;

  /// Where the photo is stored in the private avatars bucket.
  final String? avatarPath;

  /// Signed link to show the photo. Not stored in the database.
  final String? avatarUrl;

  bool get isPaired => coupleId != null;

  factory Profile.fromMap(Map<String, dynamic> row) {
    final birthday = row['birthday'] as String?;
    return Profile(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      coupleId: row['couple_id'] as String?,
      birthday: birthday == null ? null : DateTime.parse(birthday),
      avatarPath: row['avatar_path'] as String?,
    );
  }

  Profile withAvatarUrl(String? url) => Profile(
        userId: userId,
        displayName: displayName,
        coupleId: coupleId,
        birthday: birthday,
        avatarPath: avatarPath,
        avatarUrl: url,
      );
}
