import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidflow/core/constants/app_colors.dart';
import 'package:vidflow/providers/gemma_providers.dart';
import 'package:vidflow/providers/providers.dart';
import 'package:vidflow/widgets/gradient_background.dart';

class PromptInputCard extends ConsumerStatefulWidget {
  const PromptInputCard({
    super.key,
    required this.onGenerate,
  });

  final Future<void> Function(String prompt) onGenerate;

  @override
  ConsumerState<PromptInputCard> createState() => _PromptInputCardState();
}

class _PromptInputCardState extends ConsumerState<PromptInputCard> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;
    if (!ref.read(promptImageProvider).canGenerateVideo) return;

    ref.read(generationStateProvider.notifier).setGenerating(true);
    try {
      await widget.onGenerate(prompt);
      _controller.clear();
      _focusNode.unfocus();
    } finally {
      ref.read(generationStateProvider.notifier).setGenerating(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = ref.watch(generationStateProvider);
    final recentPrompts = ref.watch(recentPromptsProvider);
    final promptImage = ref.watch(promptImageProvider);
    final canGenerate = promptImage.canGenerateVideo;

    ref.listen(promptDraftProvider, (previous, next) {
      if (!canGenerate) return;
      if (next.isNotEmpty && next != _controller.text) {
        _controller.text = next;
        _controller.selection = TextSelection.collapsed(offset: next.length);
      }
    });

    ref.listen(promptImageProvider, (previous, next) {
      if (!next.canGenerateVideo) {
        _controller.clear();
        _focusNode.unfocus();
      }
    });

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
                  gradient: const LinearGradient(
                    colors: AppColors.accentGradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.black),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Describe your video',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      canGenerate
                          ? 'AI generates a short clip from your prompt'
                          : 'Pick a start image above first',
                      style: TextStyle(
                        fontSize: 13,
                        color: canGenerate
                            ? AppColors.textSecondary
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!canGenerate) ...[
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
              child: Text(
                promptImage.isUploading
                    ? 'Waiting for start frame upload…'
                    : 'Add a photo in Image to prompt above. Runway needs that image as the first video frame.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 4,
            minLines: 3,
            readOnly: !canGenerate || isGenerating,
            enableInteractiveSelection: canGenerate && !isGenerating,
            textInputAction: TextInputAction.done,
            onSubmitted:
                isGenerating || !canGenerate ? null : (_) => _submit(),
            decoration: InputDecoration(
              hintText: canGenerate
                  ? 'e.g. A neon cityscape at night with rain reflections...'
                  : 'Pick a start image above to write a prompt',
            ),
          ),
          const SizedBox(height: 16),
          recentPrompts.when(
            data: (prompts) {
              if (prompts.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent prompts',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: prompts.map((prompt) {
                      return ActionChip(
                        label: Text(
                          prompt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: isGenerating || !canGenerate
                            ? null
                            : () {
                                _controller.text = prompt;
                                _focusNode.requestFocus();
                              },
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isGenerating || !canGenerate
                    ? null
                    : const LinearGradient(colors: AppColors.accentGradient),
                color: isGenerating || !canGenerate ? AppColors.surface : null,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ElevatedButton(
                onPressed: isGenerating || !canGenerate ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Generating...',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Generate Video',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
