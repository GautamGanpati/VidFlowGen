import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:vidflow/core/config/env.dart';
import 'package:vidflow/core/config/gemma_config.dart';
import 'package:vidflow/services/gemma_vision_service.dart';

/// Downloads the Gemma model on the **main isolate**.
///
/// `background_downloader` progress events only flow on the UI isolate, so
/// downloads must not run inside a worker isolate.
Future<void> ensureGemmaModelDownloaded({
  required void Function(GemmaVisionState state) onStateChanged,
}) async {
  if (GemmaConfig.requiresHuggingFaceAuth && !Env.huggingFaceIsConfigured) {
    throw StateError(
      'Add HUGGING_FACE_TOKEN to .env and accept the ${GemmaConfig.huggingFaceModelId} '
      'license on Hugging Face before downloading (${GemmaConfig.modelSizeLabel}).',
    );
  }

  final installed =
      await FlutterGemma.isModelInstalled(GemmaConfig.modelFilename);

  if (!installed) {
    onStateChanged(
      const GemmaVisionState(
        phase: GemmaVisionPhase.downloading,
        downloadProgress: 0,
      ),
    );
  }

  try {
    var builder = FlutterGemma.installModel(
      modelType: GemmaConfig.modelType,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(
      GemmaConfig.modelUrl,
      token:
          GemmaConfig.requiresHuggingFaceAuth ? Env.huggingFaceToken : null,
      foreground: true,
    );

    if (!installed) {
      builder = builder.withProgress((progress) {
        onStateChanged(
          GemmaVisionState(
            phase: GemmaVisionPhase.downloading,
            downloadProgress: progress.toDouble(),
          ),
        );
      });
    }

    // Idempotent: skips download when present, always sets the correct active model.
    await builder.install();
  } catch (e) {
    final message = _downloadErrorMessage(e);
    onStateChanged(
      GemmaVisionState(
        phase: GemmaVisionPhase.error,
        errorMessage: message,
      ),
    );
    throw StateError(message);
  }
}

String _downloadErrorMessage(Object error) {
  final detail = '$error';
  if (detail.contains('401') || detail.contains('unauthorized')) {
    return 'Hugging Face token is invalid. Check HUGGING_FACE_TOKEN in .env.';
  }
  if (detail.contains('403') || detail.contains('forbidden')) {
    return 'Accept the ${GemmaConfig.huggingFaceModelId} license on Hugging Face, '
        'then try again.';
  }
  if (detail.contains('404') || detail.contains('not found')) {
    return 'Model file not found on Hugging Face. Check ${GemmaConfig.modelUrl}.';
  }
  return detail;
}
