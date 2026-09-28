/// One person. Mirrors a row in the `profiles` table.
class Profile {
  const Profile({
    required this.userId,
    required this.displayName,
    this.coupleId,
  });

  final String userId;
  final String displayName;

  /// Null until the person starts or joins a couple.
  final String? coupleId;

  bool get isPaired => coupleId != null;

  factory Profile.fromMap(Map<String, dynamic> row) {
    return Profile(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      coupleId: row['couple_id'] as String?,
    );
  }
}
