import 'dart:typed_data';

/// Start frame picked in the image-to-prompt flow for Runway video generation.
class PromptImageState {
  const PromptImageState({
    this.bytes,
    this.publicUrl,
    this.isUploading = false,
    this.uploadError,
  });

  final Uint8List? bytes;
  final String? publicUrl;
  final bool isUploading;
  final String? uploadError;

  bool get hasImage => bytes != null && bytes!.isNotEmpty;

  bool get canGenerateVideo =>
      publicUrl != null && publicUrl!.trim().isNotEmpty && !isUploading;

  PromptImageState copyWith({
    Uint8List? bytes,
    String? publicUrl,
    bool? isUploading,
    String? uploadError,
    bool clearBytes = false,
    bool clearPublicUrl = false,
    bool clearUploadError = false,
  }) {
    return PromptImageState(
      bytes: clearBytes ? null : (bytes ?? this.bytes),
      publicUrl: clearPublicUrl ? null : (publicUrl ?? this.publicUrl),
      isUploading: isUploading ?? this.isUploading,
      uploadError: clearUploadError ? null : (uploadError ?? this.uploadError),
    );
  }
}
