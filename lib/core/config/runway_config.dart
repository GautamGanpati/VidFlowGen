/// Runway image-to-video defaults (gen3a_turbo).
abstract final class RunwayConfig {
  static const model = 'gen3a_turbo';
  static const ratio = '1280:768';
  static const duration = 10;
  static const watermark = false;

  /// Runway requires a public image URL as the first frame (uploaded from image-to-prompt).
  static const pollInterval = Duration(seconds: 5);
  static const maxPollAttempts = 120; // ~10 minutes
}
