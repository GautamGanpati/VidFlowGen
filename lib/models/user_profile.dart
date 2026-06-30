class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.videosGenerated = 0,
    this.videosDownloaded = 0,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final int videosGenerated;
  final int videosDownloaded;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Creator',
      avatarUrl: json['avatar_url'] as String?,
      videosGenerated: json['videos_generated'] as int? ?? 0,
      videosDownloaded: json['videos_downloaded'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'videos_generated': videosGenerated,
        'videos_downloaded': videosDownloaded,
      };
}
