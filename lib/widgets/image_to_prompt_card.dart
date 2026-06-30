import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vidflow/core/config/env.dart';
import 'package:vidflow/core/config/gemma_config.dart';
import 'package:vidflow/core/constants/app_colors.dart';
import 'package:vidflow/providers/gemma_providers.dart';
import 'package:vidflow/services/gemma_vision_service.dart';
import 'package:vidflow/widgets/gradient_background.dart';

class ImageToPromptCard extends ConsumerStatefulWidget {
  const ImageToPromptCard({super.key});

  @override
  ConsumerState<ImageToPromptCard> createState() => _ImageToPromptCardState();
}

class _ImageToPromptCardState extends ConsumerState<ImageToPromptCard> {
  final _picker = ImagePicker();
  String? _description;
  bool _isBusy = false;

  bool get _gemmaReady =>
      !GemmaConfig.requiresHuggingFaceAuth || Env.huggingFaceIsConfigured;

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1024,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() => _description = null);
    ref.read(gemmaVisionStateProvider.notifier).resetError();
    await ref.read(promptImageProvider.notifier).setFromPicker(bytes);
  }

  Future<void> _describeImage() async {
    final bytes = ref.read(promptImageProvider).bytes;
    if (bytes == null) return;

    setState(() => _isBusy = true);
    ref.read(gemmaVisionStateProvider.notifier).update(
      const GemmaVisionState(phase: GemmaVisionPhase.downloading, downloadProgress: 0),
    );

    try {
      final service = ref.read(gemmaVisionServiceProvider);
      final text = await service.describeImage(
        bytes,
        onStateChanged: (state) {
          ref.read(gemmaVisionStateProvider.notifier).update(state);
        },
      );

      if (mounted) {
        setState(() => _description = text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.errorContainer,
            content: Text(
              'Image description failed: $e',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _useAsPrompt() {
    final text = _description;
    if (text == null || text.isEmpty) return;
    if (!ref.read(promptImageProvider).canGenerateVideo) return;

    ref.read(promptDraftProvider.notifier).set(text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompt filled — edit or generate below')),
    );
  }

  Future<void> _copyDescription() async {
    final text = _description;
    if (text == null || text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompt copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gemmaState = ref.watch(gemmaVisionStateProvider);
    final promptImage = ref.watch(promptImageProvider);
    final imageBytes = promptImage.bytes;
    final phase = gemmaState.phase;
    final progress = gemmaState.downloadProgress;
    final showProgressBar = phase == GemmaVisionPhase.downloading ||
        phase == GemmaVisionPhase.loading;
    final statusText = switch (phase) {
      GemmaVisionPhase.downloading => progress != null
          ? 'Downloading Gemma model… ${progress.toStringAsFixed(0)}%'
          : 'Downloading Gemma model…',
      GemmaVisionPhase.loading =>
        'Loading model into memory… first run can take 1–2 min on 8 GB phones',
      GemmaVisionPhase.describing => 'Analyzing image…',
      _ => null,
    };

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentTertiary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accentTertiary.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.accentTertiary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Image to prompt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Pick a photo — Gemma describes it as a video prompt',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (phase == GemmaVisionPhase.error &&
              gemmaState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      gemmaState.errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!_gemmaReady) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.45),
                ),
              ),
              child: const Text(
                'Add HUGGING_FACE_TOKEN to .env to enable on-device Gemma vision.',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(imageBytes, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (promptImage.isUploading) ...[
            const LinearProgressIndicator(
              backgroundColor: AppColors.surface,
              color: AppColors.accentTertiary,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Uploading start frame for video generation…',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (promptImage.uploadError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                promptImage.uploadError!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.error,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showProgressBar || statusText != null) ...[
            if (showProgressBar)
              LinearProgressIndicator(
                value: phase == GemmaVisionPhase.downloading && progress != null
                    ? progress / 100
                    : null,
                backgroundColor: AppColors.surface,
                color: AppColors.accentTertiary,
                borderRadius: BorderRadius.circular(4),
              ),
            if (statusText != null) ...[
              SizedBox(height: showProgressBar ? 8 : 0),
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          if (_description != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Generated prompt',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _copyDescription,
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Copy prompt',
                        visualDensity: VisualDensity.compact,
                        color: AppColors.accentTertiary,
                      ),
                    ],
                  ),
                  Text(
                    _description!,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : _pickImage,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 20,
                  ),
                  label: Text(imageBytes == null ? 'Pick image' : 'Change'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _isBusy || imageBytes == null || !_gemmaReady
                      ? null
                      : _describeImage,
                  icon: _isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : const Icon(Icons.document_scanner_outlined, size: 20),
                  label: Text(
                    _isBusy
                        ? switch (phase) {
                            GemmaVisionPhase.downloading => 'Downloading…',
                            GemmaVisionPhase.loading => 'Loading…',
                            _ => 'Analyzing…',
                          }
                        : 'Describe',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentTertiary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_description != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: promptImage.canGenerateVideo ? _useAsPrompt : null,
                icon: const Icon(Icons.arrow_downward_rounded),
                label: const Text('Use as video prompt'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
