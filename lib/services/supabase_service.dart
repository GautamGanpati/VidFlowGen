import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vidflow/core/config/env.dart';
import 'package:vidflow/models/generated_video.dart';
import 'package:vidflow/models/user_profile.dart';

class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize() async {
    if (!Env.supabaseIsConfigured) return;

    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );

    // Sign in anonymously if there is no current session
    if (client.auth.currentSession == null) {
      try {
        await client.auth.signInAnonymously();
      } catch (e) {
        // Log the error but don't crash; anonymous auth might be disabled or user offline
        debugPrint('Supabase anonymous sign-in failed: $e');
      }
    }
  }

  String? get currentUserId => client.auth.currentUser?.id;

  Future<UserProfile> getProfile() async {
    final userId = currentUserId;
    if (userId == null) {
      return const UserProfile(
        id: 'guest',
        displayName: 'Guest Creator',
      );
    }

    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return UserProfile(id: userId, displayName: 'Creator');
    }

    return UserProfile.fromJson(response);
  }

  Future<List<GeneratedVideo>> fetchVideos({String? userId}) async {
    final uid = userId ?? currentUserId;
    if (uid == null) return [];

    final response = await client
        .from('generated_videos')
        .select()
        .eq('user_id', uid)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => GeneratedVideo.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<GeneratedVideo> createVideoRecord({
    required String prompt,
    required String userId,
  }) async {
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(days: 3));

    final response = await client
        .from('generated_videos')
        .insert({
          'user_id': userId,
          'prompt': prompt,
          'status': VideoStatus.pending.name,
          'created_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        })
        .select()
        .single();

    return GeneratedVideo.fromJson(response);
  }

  Future<GeneratedVideo> updateVideoStatus(
    String videoId,
    VideoStatus status, {
    String? videoUrl,
    String? thumbnailUrl,
    String? storagePath,
    int? durationSeconds,
  }) async {
    final updates = <String, dynamic>{'status': status.name};
    if (videoUrl != null) updates['video_url'] = videoUrl;
    if (thumbnailUrl != null) updates['thumbnail_url'] = thumbnailUrl;
    if (storagePath != null) updates['storage_path'] = storagePath;
    if (durationSeconds != null) {
      updates['duration_seconds'] = durationSeconds;
    }

    final response = await client
        .from('generated_videos')
        .update(updates)
        .eq('id', videoId)
        .select()
        .single();

    return GeneratedVideo.fromJson(response);
  }

  Future<String> uploadVideo(String userId, String videoId, Uint8List bytes) {
    final path = '$userId/$videoId.mp4';
    return client.storage
        .from('generated-videos')
        .uploadBinary(path, bytes)
        .then((_) => client.storage.from('generated-videos').getPublicUrl(path));
  }

  Future<String> uploadPromptImage(String userId, Uint8List bytes) async {
    Object? functionError;
    try {
      return await _uploadPromptImageViaFunction(userId, bytes);
    } catch (e) {
      functionError = e;
    }

    try {
      return await _uploadPromptImageDirect(userId, bytes);
    } catch (directError) {
      throw _promptImageUploadError(
        'edge function: $functionError; direct upload: $directError',
      );
    }
  }

  Future<String> _uploadPromptImageViaFunction(
    String userId,
    Uint8List bytes,
  ) async {
    final response = await client.functions.invoke(
      Env.uploadPromptImageFunction,
      body: {
        'user_id': userId,
        'image_base64': base64Encode(bytes),
        'content_type': 'image/jpeg',
      },
    );

    if (response.status != 200) {
      final data = response.data;
      final detail = data is Map ? data['error'] : data;
      throw Exception('$detail (HTTP ${response.status})');
    }

    final data = response.data as Map<String, dynamic>;
    final publicUrl = data['public_url'] as String?;
    if (publicUrl == null || publicUrl.isEmpty) {
      throw Exception('Upload succeeded but no public_url returned');
    }
    return publicUrl;
  }

  Future<String> _uploadPromptImageDirect(String userId, Uint8List bytes) async {
    final imageId = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/$imageId.jpg';
    await client.storage.from('prompt-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return client.storage.from('prompt-images').getPublicUrl(path);
  }

  Exception _promptImageUploadError(String detail) {
    return Exception(
      'Start frame upload failed ($detail). '
      'Fix: Supabase Dashboard → SQL Editor → run '
      'supabase/setup/prompt-images-bucket.sql '
      'OR deploy: supabase functions deploy upload-prompt-image',
    );
  }

  Stream<List<GeneratedVideo>> watchVideos(String userId) {
    return client
        .from('generated_videos')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) => GeneratedVideo.fromJson(row))
              .where((v) => !v.isExpired)
              .toList(),
        );
  }
}
