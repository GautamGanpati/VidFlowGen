import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vidflow/core/config/env.dart';
import 'package:vidflow/core/config/runway_config.dart';
import 'package:vidflow/models/generated_video.dart';
import 'package:vidflow/services/runway_service.dart';
import 'package:vidflow/services/supabase_service.dart';

class VideoGenerationService {
  VideoGenerationService(
    this._supabase, {
    RunwayService? runway,
  }) : _runway = runway;

  final SupabaseService _supabase;
  final RunwayService? _runway;

  Future<GeneratedVideo> generate({
    required String prompt,
    required String userId,
    required String videoId,
    String? promptImageUrl,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) async {
    if (Env.runwayIsConfigured) {
      return _generateWithRunway(
        prompt: prompt,
        userId: userId,
        videoId: videoId,
        promptImageUrl: promptImageUrl,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );
    }

    if (Env.supabaseIsConfigured) {
      return _generateWithEdgeFunction(
        prompt: prompt,
        userId: userId,
        videoId: videoId,
      );
    }

    return _mockGenerate(
      prompt: prompt,
      userId: userId,
      videoId: videoId,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  Future<GeneratedVideo> _generateWithRunway({
    required String prompt,
    required String userId,
    required String videoId,
    String? promptImageUrl,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) async {
    final imageUrl = promptImageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw ArgumentError(
        'A public start-frame image URL is required for Runway generation',
      );
    }

    final runway = _runway ?? RunwayService();

    if (Env.supabaseIsConfigured) {
      await _supabase.updateVideoStatus(videoId, VideoStatus.processing);
    }

    try {
      final videoUrl = await runway.generateVideoUrl(
        promptText: prompt,
        promptImageUrl: imageUrl,
      );

      if (Env.supabaseIsConfigured) {
        return _supabase.updateVideoStatus(
          videoId,
          VideoStatus.completed,
          videoUrl: videoUrl,
          durationSeconds: RunwayConfig.duration,
        );
      }

      final now = createdAt ?? DateTime.now();
      return GeneratedVideo(
        id: videoId,
        userId: userId,
        prompt: prompt,
        status: VideoStatus.completed,
        createdAt: now,
        expiresAt: expiresAt ?? now.add(const Duration(days: 3)),
        videoUrl: videoUrl,
        durationSeconds: RunwayConfig.duration,
      );
    } catch (e) {
      if (Env.supabaseIsConfigured) {
        await _supabase.updateVideoStatus(videoId, VideoStatus.failed);
      }
      rethrow;
    }
  }

  Future<GeneratedVideo> _generateWithEdgeFunction({
    required String prompt,
    required String userId,
    required String videoId,
  }) async {
    try {
      await _supabase.updateVideoStatus(
        videoId,
        VideoStatus.processing,
      );

      final response = await _supabase.client.functions.invoke(
        Env.aiGenerationFunction,
        body: {
          'prompt': prompt,
          'video_id': videoId,
          'user_id': userId,
        },
      );

      if (response.status != 200) {
        throw Exception('Generation failed: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      return _supabase.updateVideoStatus(
        videoId,
        VideoStatus.completed,
        videoUrl: data['video_url'] as String?,
        thumbnailUrl: data['thumbnail_url'] as String?,
        storagePath: data['storage_path'] as String?,
        durationSeconds: data['duration_seconds'] as int?,
      );
    } on FunctionException catch (e) {
      await _supabase.updateVideoStatus(videoId, VideoStatus.failed);
      throw Exception('AI generation error: ${e.details}');
    }
  }

  Future<GeneratedVideo> _mockGenerate({
    required String prompt,
    required String userId,
    required String videoId,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));

    final now = createdAt ?? DateTime.now();
    return GeneratedVideo(
      id: videoId,
      userId: userId,
      prompt: prompt,
      status: VideoStatus.completed,
      createdAt: now,
      expiresAt: expiresAt ?? now.add(const Duration(days: 3)),
      thumbnailUrl: 'https://picsum.photos/seed/$videoId/400/700',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      durationSeconds: 15,
    );
  }
}
