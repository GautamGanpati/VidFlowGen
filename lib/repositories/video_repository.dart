import 'package:uuid/uuid.dart';
import 'package:vidflow/core/config/env.dart';
import 'package:vidflow/models/generated_video.dart';
import 'package:vidflow/services/download_service.dart';
import 'package:vidflow/services/supabase_service.dart';
import 'package:vidflow/services/turso_service.dart';
import 'package:vidflow/services/video_generation_service.dart';

class VideoRepository {
  VideoRepository({
    required SupabaseService supabase,
    required TursoService turso,
    required VideoGenerationService generation,
    required DownloadService download,
  })  : _supabase = supabase,
        _turso = turso,
        _generation = generation,
        _download = download;

  final SupabaseService _supabase;
  final TursoService _turso;
  final VideoGenerationService _generation;
  final DownloadService _download;
  final _uuid = const Uuid();

  String get _userId => _supabase.currentUserId ?? 'local-${_uuid.v4()}';

  Future<List<GeneratedVideo>> getVideos() async {
    await _turso.purgeExpired();

    if (Env.supabaseIsConfigured) {
      try {
        final videos = await _supabase.fetchVideos(userId: _userId);
        for (final video in videos) {
          await _turso.cacheVideo(video);
        }
        return videos;
      } catch (_) {
        return _turso.getCachedVideos(_userId);
      }
    }

    return _turso.getCachedVideos(_userId);
  }

  Future<List<String>> getRecentPrompts() {
    return _turso.getRecentPrompts(_userId);
  }

  Future<GeneratedVideo> generateFromPrompt(
    String prompt, {
    required String promptImageUrl,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Prompt cannot be empty');
    }
    if (promptImageUrl.trim().isEmpty) {
      throw ArgumentError('Start image URL is required for video generation');
    }

    await _turso.logPrompt(_userId, trimmed);

    GeneratedVideo record;
    if (Env.supabaseIsConfigured) {
      final uid = _supabase.currentUserId;
      if (uid == null) {
        throw StateError(
          'Supabase is configured but you are not signed in. '
          'Please enable Anonymous Sign-in in your Supabase Dashboard (Authentication → Providers → Anonymous) '
          'so that a valid authenticated session can be initialized.'
        );
      }
      record = await _supabase.createVideoRecord(
        prompt: trimmed,
        userId: uid,
      );
    } else {
      record = GeneratedVideo(
        id: _uuid.v4(),
        userId: _userId,
        prompt: trimmed,
        status: VideoStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 3)),
      );
    }

    final result = await _generation.generate(
      prompt: trimmed,
      userId: _userId,
      videoId: record.id,
      promptImageUrl: promptImageUrl,
      createdAt: record.createdAt,
      expiresAt: record.expiresAt,
    );

    await _turso.cacheVideo(result);
    return result;
  }

  Future<String> downloadVideo(GeneratedVideo video) {
    return _download.downloadVideo(video);
  }
}
