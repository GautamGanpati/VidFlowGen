import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:vidflow/core/config/gemma_config.dart';
import 'package:vidflow/services/gemma/gemma_model_downloader.dart';

enum GemmaVisionPhase {
  idle,
  initializing,
  downloading,
  loading,
  ready,
  describing,
  error,
}

class GemmaVisionState {
  const GemmaVisionState({
    this.phase = GemmaVisionPhase.idle,
    this.downloadProgress,
    this.errorMessage,
  });

  final GemmaVisionPhase phase;
  final double? downloadProgress;
  final String? errorMessage;

  GemmaVisionState copyWith({
    GemmaVisionPhase? phase,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return GemmaVisionState(
      phase: phase ?? this.phase,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage,
    );
  }
}

/// On-device Gemma vision — download on main isolate; inference on main isolate
/// too (LiteRT offloads engine creation to a native background thread internally).
class GemmaVisionService {
  InferenceModel? _model;
  GemmaVisionState _state = const GemmaVisionState();

  GemmaVisionState get state => _state;

  Future<void> ensureModelReady({
    void Function(GemmaVisionState state)? onStateChanged,
  }) async {
    void forward(GemmaVisionState state) => _updateState(state, onStateChanged);

    await ensureGemmaModelDownloaded(onStateChanged: forward);
    await _loadModel(forward);
  }

  Future<String> describeImage(
    Uint8List imageBytes, {
    void Function(GemmaVisionState state)? onStateChanged,
  }) async {
    void forward(GemmaVisionState state) => _updateState(state, onStateChanged);

    await ensureGemmaModelDownloaded(onStateChanged: forward);
    await _loadModel(forward);

    forward(const GemmaVisionState(phase: GemmaVisionPhase.describing));

    try {
      final model = _model!;
      final chat = await model.createChat(
        maxOutputTokens: GemmaConfig.maxOutputTokens,
        systemInstruction:
            'You are a creative director writing concise video prompts from photos.',
      );

      await chat.addQueryChunk(
        Message.withImages(
          text: GemmaConfig.describePrompt,
          imageBytes: [imageBytes],
          isUser: true,
        ),
      );

      final response = await chat.generateChatResponse();
      final text = switch (response) {
        TextResponse(:final token) => token.trim(),
        _ => '',
      };

      if (text.isEmpty) {
        throw StateError('Gemma returned an empty description');
      }

      forward(const GemmaVisionState(phase: GemmaVisionPhase.ready));
      return text;
    } catch (e) {
      final message = '$e';
      forward(
        GemmaVisionState(phase: GemmaVisionPhase.error, errorMessage: message),
      );
      rethrow;
    }
  }

  Future<void> _loadModel(void Function(GemmaVisionState state) forward) async {
    if (_model != null) {
      forward(const GemmaVisionState(phase: GemmaVisionPhase.ready));
      return;
    }

    final installed = await FlutterGemma.isModelInstalled(
      GemmaConfig.modelFilename,
    );
    if (!installed) {
      throw StateError(
        'Gemma model is not installed. Download it first (${GemmaConfig.modelSizeLabel}).',
      );
    }

    forward(const GemmaVisionState(phase: GemmaVisionPhase.loading));

    // Yield so the loading indicator paints before native mmap / engine init.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    try {
      _model = await _loadModelWithFallback();
      forward(const GemmaVisionState(phase: GemmaVisionPhase.ready));
    } catch (e) {
      final message = _engineErrorMessage(e);
      forward(
        GemmaVisionState(phase: GemmaVisionPhase.error, errorMessage: message),
      );
      throw StateError(message);
    }
  }

  Future<InferenceModel> _loadModelWithFallback() async {
    Object? lastError;

    for (final backend in GemmaConfig.loadBackends) {
      try {
        return await FlutterGemma.getActiveModel(
          maxTokens: GemmaConfig.maxTokens,
          preferredBackend: backend,
          supportImage: true,
          supportAudio: false,
          maxNumImages: GemmaConfig.maxNumImages,
          enableSpeculativeDecoding: false,
          maxConcurrentSessions: 1,
        );
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ?? StateError('Failed to create Gemma engine');
  }

  String _engineErrorMessage(Object error) {
    final detail = '$error';
    if (detail.contains('Failed to create engine') ||
        detail.contains('OutOfMemory') ||
        detail.contains('memory')) {
      return 'Gemma ran out of memory on this device. '
          'Close other apps, then try again. '
          'If it keeps failing, clear Vidflow storage and re-download '
          '(${GemmaConfig.modelSizeLabel}).';
    }
    return detail;
  }

  void _updateState(
    GemmaVisionState next,
    void Function(GemmaVisionState state)? onStateChanged,
  ) {
    _state = next;
    onStateChanged?.call(next);
  }

  Future<void> dispose() async {
    await _model?.close();
    _model = null;
    _state = const GemmaVisionState();
  }
}
