import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vidflow/core/config/env.dart';
import 'package:vidflow/models/generated_video.dart';

/// Edge metadata cache via Turso's HTTP pipeline API.
/// Supabase remains the source of truth for video files and auth.
class TursoService {
  TursoService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  bool get isConfigured => Env.tursoIsConfigured;

  String get _httpUrl {
    var url = Env.tursoDatabaseUrl.trim();
    if (url.isEmpty) return '';

    if (url.startsWith('libsql://')) {
      url = 'https://${url.replaceFirst('libsql://', '')}';
    }

    url = url.replaceAll(RegExp(r'/v2/pipeline/?$'), '');
    return url.replaceAll(RegExp(r'/$'), '');
  }

  Future<void> initializeSchema() async {
    if (!isConfigured) return;

    try {
      await _execute([
        '''
        CREATE TABLE IF NOT EXISTS video_cache (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          prompt TEXT NOT NULL,
          status TEXT NOT NULL,
          thumbnail_url TEXT,
          video_url TEXT,
          created_at TEXT NOT NULL,
          expires_at TEXT NOT NULL,
          synced_at TEXT NOT NULL
        )
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_video_cache_user
        ON video_cache(user_id, created_at DESC)
        ''',
      ]);
    } on DioException catch (e) {
      debugPrint(
        'Turso schema init skipped (${e.response?.statusCode ?? 'network'}): '
        '${e.message}',
      );
    }
  }

  Future<void> cacheVideo(GeneratedVideo video) async {
    if (!isConfigured) return;

    try {
      await _execute([
        '''
        INSERT OR REPLACE INTO video_cache
          (id, user_id, prompt, status, thumbnail_url, video_url, created_at, expires_at, synced_at)
        VALUES
          ('${video.id}', '${video.userId}', ${_quote(video.prompt)}, '${video.status.name}',
           ${_nullable(video.thumbnailUrl)}, ${_nullable(video.videoUrl)},
           '${video.createdAt.toIso8601String()}', '${video.expiresAt.toIso8601String()}',
           '${DateTime.now().toUtc().toIso8601String()}')
        ''',
      ]);
    } on DioException catch (e) {
      debugPrint('Turso cache write failed: ${e.message}');
    }
  }

  Future<List<GeneratedVideo>> getCachedVideos(String userId) async {
    if (!isConfigured) return [];

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final result = await _query(
        '''
        SELECT * FROM video_cache
        WHERE user_id = '$userId' AND expires_at > '$now'
        ORDER BY created_at DESC
        ''',
      );

      return result.map(_rowToVideo).toList();
    } on DioException catch (e) {
      debugPrint('Turso cache read failed: ${e.message}');
      return [];
    }
  }

  Future<void> logPrompt(String userId, String prompt) async {
    if (!isConfigured) return;

    try {
      await _execute([
        '''
        CREATE TABLE IF NOT EXISTS prompt_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          prompt TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
        ''',
        '''
        INSERT INTO prompt_history (user_id, prompt, created_at)
        VALUES ('$userId', ${_quote(prompt)}, '${DateTime.now().toUtc().toIso8601String()}')
        ''',
      ]);
    } on DioException catch (e) {
      debugPrint('Turso prompt log failed: ${e.message}');
    }
  }

  Future<List<String>> getRecentPrompts(String userId, {int limit = 5}) async {
    if (!isConfigured) return [];

    try {
      final result = await _query(
        '''
        SELECT prompt FROM prompt_history
        WHERE user_id = '$userId'
        ORDER BY created_at DESC
        LIMIT $limit
        ''',
      );

      return result
          .map((row) => row['prompt'] as String? ?? '')
          .where((p) => p.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      debugPrint('Turso prompt read failed: ${e.message}');
      return [];
    }
  }

  Future<void> purgeExpired() async {
    if (!isConfigured) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _execute([
        "DELETE FROM video_cache WHERE expires_at <= '$now'",
      ]);
    } on DioException catch (e) {
      debugPrint('Turso purge failed: ${e.message}');
    }
  }

  Future<void> _execute(List<String> statements) async {
    await _dio.post(
      '$_httpUrl/v2/pipeline',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${Env.tursoAuthToken}',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'requests': [
          for (final sql in statements)
            {
              'type': 'execute',
              'stmt': {'sql': sql},
            },
          {'type': 'close'},
        ],
      },
    );
  }

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final response = await _dio.post(
      '$_httpUrl/v2/pipeline',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${Env.tursoAuthToken}',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'requests': [
          {'type': 'execute', 'stmt': {'sql': sql}},
          {'type': 'close'},
        ],
      },
    );

    final results = response.data['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) return [];

    final result = results.first as Map<String, dynamic>;
    if (result['type'] == 'error') {
      throw DioException(
        requestOptions: response.requestOptions,
        message: result['error']?.toString(),
      );
    }

    final responseBody = result['response'] as Map<String, dynamic>?;
    if (responseBody == null) return [];

    final resultSet = responseBody['result'] as Map<String, dynamic>?;
    if (resultSet == null) return [];

    final columns = (resultSet['cols'] as List<dynamic>)
        .map((c) => (c as Map<String, dynamic>)['name'] as String)
        .toList();
    final rows = resultSet['rows'] as List<dynamic>? ?? [];

    return rows.map((row) {
      final values = (row as List<dynamic>);
      return {
        for (var i = 0; i < columns.length; i++)
          columns[i]: values[i] is Map ? values[i]['value'] : values[i],
      };
    }).toList();
  }

  GeneratedVideo _rowToVideo(Map<String, dynamic> row) {
    return GeneratedVideo(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      prompt: row['prompt'] as String,
      status: VideoStatus.fromString(row['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(row['created_at'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
      thumbnailUrl: row['thumbnail_url'] as String?,
      videoUrl: row['video_url'] as String?,
    );
  }

  String _quote(String value) => "'${value.replaceAll("'", "''")}'";
  String _nullable(String? value) => value == null ? 'NULL' : _quote(value);
}
