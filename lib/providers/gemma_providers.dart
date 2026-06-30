import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidflow/core/config/env.dart';
import 'package:vidflow/models/prompt_image.dart';
import 'package:vidflow/services/gemma_vision_service.dart';
import 'package:vidflow/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

final gemmaVisionServiceProvider = Provider<GemmaVisionService>((ref) {
  final service = GemmaVisionService();
  ref.onDispose(service.dispose);
  return service;
});

final gemmaVisionStateProvider =
    NotifierProvider<GemmaVisionStateNotifier, GemmaVisionState>(
  GemmaVisionStateNotifier.new,
);

class GemmaVisionStateNotifier extends Notifier<GemmaVisionState> {
  @override
  GemmaVisionState build() => const GemmaVisionState();

  void update(GemmaVisionState state) => this.state = state;

  void resetError() {
    if (state.phase == GemmaVisionPhase.error) {
      state = const GemmaVisionState(phase: GemmaVisionPhase.idle);
    }
  }
}

final promptDraftProvider = NotifierProvider<PromptDraftNotifier, String>(
  PromptDraftNotifier.new,
);

class PromptDraftNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;

  void clear() => state = '';
}

final promptImageProvider =
    NotifierProvider<PromptImageNotifier, PromptImageState>(
  PromptImageNotifier.new,
);

class PromptImageNotifier extends Notifier<PromptImageState> {
  static const _uuid = Uuid();

  @override
  PromptImageState build() => const PromptImageState();

  Future<void> setFromPicker(Uint8List bytes) async {
    state = PromptImageState(
      bytes: bytes,
      isUploading: true,
    );
    ref.read(promptDraftProvider.notifier).clear();

    if (!Env.supabaseIsConfigured) {
      state = state.copyWith(
        isUploading: false,
        uploadError:
            'Add Supabase credentials to .env so start frames can be uploaded for Runway.',
      );
      return;
    }

    try {
      final supabase = SupabaseService();
      final userId = supabase.currentUserId ?? 'local-${_uuid.v4()}';
      final publicUrl = await supabase.uploadPromptImage(userId, bytes);
      state = state.copyWith(
        publicUrl: publicUrl,
        isUploading: false,
        clearUploadError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        uploadError: 'Failed to upload start frame: $e',
        clearPublicUrl: true,
      );
    }
  }

  void clear() {
    state = const PromptImageState();
    ref.read(promptDraftProvider.notifier).clear();
  }
}
