import 'package:flutter_gemma/flutter_gemma.dart';

abstract final class GemmaConfig {
  /// Gemma 4 E4B — higher quality multimodal build (~4.3 GB on disk).
  /// https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm
  ///
  /// Needs more RAM than E2B; 12 GB+ recommended. On 8 GB phones, close other
  /// apps before the first load. Switch back to E2B in this file if it OOMs.
  static const huggingFaceModelId = 'litert-community/gemma-4-E4B-it-litert-lm';

  static const modelType = ModelType.gemma4;
  static const modelFilename = 'gemma-4-E4B-it.litertlm';

  static const modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm';

  static const modelSizeLabel = '~4.3 GB';

  /// Public repo — no Hugging Face token or license gate required.
  static const requiresHuggingFaceAuth = false;

  /// Minimum KV cache for .litertlm — keeps RAM as low as possible with E4B.
  static const maxTokens = 2048;

  static const maxOutputTokens = 512;
  static const maxNumImages = 1;

  /// CPU first avoids GPU driver memory spikes during engine init.
  static const loadBackends = [PreferredBackend.cpu, PreferredBackend.gpu];

  static const describePrompt =
      'Describe this image as a short video scene prompt. '
      'Include subject, setting, lighting, mood, and camera motion. '
      'Keep it under 80 words.';
}
