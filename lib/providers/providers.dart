import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidflow/core/config/env.dart';
import 'package:vidflow/models/generated_video.dart';
import 'package:vidflow/models/user_profile.dart';
import 'package:vidflow/providers/gemma_providers.dart';
import 'package:vidflow/repositories/video_repository.dart';
import 'package:vidflow/services/download_service.dart';
import 'package:vidflow/services/supabase_service.dart';
import 'package:vidflow/services/turso_service.dart';
import 'package:vidflow/services/runway_service.dart';
import 'package:vidflow/services/video_generation_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final tursoServiceProvider = Provider<TursoService>((ref) {
  return TursoService();
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

final videoGenerationServiceProvider = Provider<VideoGenerationService>((ref) {
  return VideoGenerationService(
    ref.watch(supabaseServiceProvider),
    runway: ref.watch(runwayServiceProvider),
  );
});

final runwayServiceProvider = Provider<RunwayService?>((ref) {
  if (!Env.runwayIsConfigured) return null;
  return RunwayService();
});

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepository(
    supabase: ref.watch(supabaseServiceProvider),
    turso: ref.watch(tursoServiceProvider),
    generation: ref.watch(videoGenerationServiceProvider),
    download: ref.watch(downloadServiceProvider),
  );
});

final videosProvider = AsyncNotifierProvider<VideosNotifier, List<GeneratedVideo>>(
  VideosNotifier.new,
);

class VideosNotifier extends AsyncNotifier<List<GeneratedVideo>> {
  @override
  Future<List<GeneratedVideo>> build() async {
    return ref.read(videoRepositoryProvider).getVideos();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(videoRepositoryProvider).getVideos(),
    );
  }

  Future<GeneratedVideo?> generate(String prompt) async {
    final promptImageUrl = ref.read(promptImageProvider).publicUrl;
    if (promptImageUrl == null || promptImageUrl.trim().isEmpty) {
      throw StateError('Pick a start image before generating a video.');
    }

    try {
      final video = await ref.read(videoRepositoryProvider).generateFromPrompt(
            prompt,
            promptImageUrl: promptImageUrl,
          );
      await refresh();
      return video;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> download(GeneratedVideo video) async {
    await ref.read(videoRepositoryProvider).downloadVideo(video);
  }
}

final recentPromptsProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(videoRepositoryProvider).getRecentPrompts();
});

final profileProvider = FutureProvider<UserProfile>((ref) async {
  return ref.read(supabaseServiceProvider).getProfile();
});

final generationStateProvider = NotifierProvider<GenerationNotifier, bool>(
  GenerationNotifier.new,
);

class GenerationNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setGenerating(bool value) => state = value;
}
