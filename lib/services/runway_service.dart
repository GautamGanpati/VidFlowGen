import 'dart:async';
import 'dart:math';

import 'package:runwayml_flutter/runwayml_flutter.dart';
import 'package:vidflow/core/config/env.dart';
import 'package:vidflow/core/config/runway_config.dart';

/// RunwayML image-to-video via [runwayml_flutter].
class RunwayService {
  RunwayService({RunwayMLClient? client})
      : _client = client ?? RunwayMLClient(apiKey: Env.runwayApiKey);

  final RunwayMLClient _client;
  final _random = Random();

  Future<String> generateVideoUrl({
    required String promptText,
    required String promptImageUrl,
    void Function(double? progress)? onProgress,
  }) async {
    if (promptImageUrl.trim().isEmpty) {
      throw ArgumentError('promptImageUrl is required for Runway image-to-video');
    }

    final task = await _client.generateVideo(
      promptImageUrl: promptImageUrl,
      model: RunwayConfig.model,
      promptText: promptText,
      ratio: RunwayConfig.ratio,
      seed: _random.nextInt(1 << 31),
      duration: RunwayConfig.duration,
      watermark: RunwayConfig.watermark,
    );

    return _pollUntilComplete(task.id, onProgress: onProgress);
  }

  Future<String> _pollUntilComplete(
    String taskId, {
    void Function(double? progress)? onProgress,
  }) async {
    for (var attempt = 0; attempt < RunwayConfig.maxPollAttempts; attempt++) {
      final status = await _client.getTaskStatus(taskId);
      onProgress?.call(status.progress);

      switch (status.status) {
        case 'SUCCEEDED':
          final url = status.output?.firstOrNull;
          if (url == null || url.isEmpty) {
            throw StateError('Runway task succeeded but returned no video URL');
          }
          return url;
        case 'FAILED':
          throw Exception(
            status.failure ?? status.failureCode ?? 'Runway generation failed',
          );
        case 'CANCELLED':
          throw Exception('Runway generation was cancelled');
      }

      await Future<void>.delayed(RunwayConfig.pollInterval);
    }

    throw TimeoutException(
      'Runway video generation timed out after '
      '${RunwayConfig.maxPollAttempts * RunwayConfig.pollInterval.inSeconds}s',
    );
  }
}
