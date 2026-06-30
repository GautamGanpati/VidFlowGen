class GeneratedVideo {
  const GeneratedVideo({
    required this.id,
    required this.userId,
    required this.prompt,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.thumbnailUrl,
    this.videoUrl,
    this.storagePath,
    this.durationSeconds,
  });

  final String id;
  final String userId;
  final String prompt;
  final VideoStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? storagePath;
  final int? durationSeconds;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isDownloadable =>
      status == VideoStatus.completed && !isExpired && videoUrl != null;

  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  GeneratedVideo copyWith({
    String? id,
    String? userId,
    String? prompt,
    VideoStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? thumbnailUrl,
    String? videoUrl,
    String? storagePath,
    int? durationSeconds,
  }) {
    return GeneratedVideo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      prompt: prompt ?? this.prompt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      storagePath: storagePath ?? this.storagePath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  factory GeneratedVideo.fromJson(Map<String, dynamic> json) {
    return GeneratedVideo(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      prompt: json['prompt'] as String,
      status: VideoStatus.fromString(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      thumbnailUrl: json['thumbnail_url'] as String?,
      videoUrl: json['video_url'] as String?,
      storagePath: json['storage_path'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'prompt': prompt,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'thumbnail_url': thumbnailUrl,
        'video_url': videoUrl,
        'storage_path': storagePath,
        'duration_seconds': durationSeconds,
      };
}

enum VideoStatus {
  pending,
  processing,
  completed,
  failed,
  expired;

  static VideoStatus fromString(String value) {
    return VideoStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => VideoStatus.pending,
    );
  }

  String get label => switch (this) {
        VideoStatus.pending => 'Queued',
        VideoStatus.processing => 'Generating',
        VideoStatus.completed => 'Ready',
        VideoStatus.failed => 'Failed',
        VideoStatus.expired => 'Expired',
      };
}
