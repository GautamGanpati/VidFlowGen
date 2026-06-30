import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
  static String get tursoDatabaseUrl => dotenv.env['TURSO_DATABASE_URL'] ?? '';
  static String get tursoAuthToken => dotenv.env['TURSO_AUTH_TOKEN'] ?? '';
  static String get aiGenerationFunction =>
      dotenv.env['AI_GENERATION_FUNCTION'] ?? 'generate-video';
  static String get uploadPromptImageFunction =>
      dotenv.env['UPLOAD_PROMPT_IMAGE_FUNCTION'] ?? 'upload-prompt-image';
  static String get huggingFaceToken => dotenv.env['HUGGING_FACE_TOKEN'] ?? '';
  static String get runwayApiKey => dotenv.env['RUNWAY_API_KEY'] ?? '';

  static bool get huggingFaceIsConfigured => !_isPlaceholder(huggingFaceToken);

  static bool get runwayIsConfigured => !_isPlaceholder(runwayApiKey);

  /// Back-compat alias for Supabase connectivity checks.
  static bool get isConfigured => supabaseIsConfigured;

  static bool get supabaseIsConfigured =>
      !_isPlaceholder(supabaseUrl) && !_isPlaceholder(supabasePublishableKey);

  static bool get tursoIsConfigured =>
      !_isPlaceholder(tursoDatabaseUrl) && !_isPlaceholder(tursoAuthToken);

  static bool _isPlaceholder(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    const markers = [
      'your-',
      'your_',
      'example',
      'changeme',
      'replace-me',
      'insert-',
    ];

    return markers.any(normalized.contains);
  }
}
