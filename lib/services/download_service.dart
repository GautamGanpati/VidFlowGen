import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vidflow/models/generated_video.dart';

class DownloadService {
  DownloadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<String> downloadVideo(GeneratedVideo video) async {
    if (!video.isDownloadable || video.videoUrl == null) {
      throw Exception('Video is not available for download');
    }

    await _requestPermission();

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/vidflow_${video.id}.mp4';

    await _dio.download(video.videoUrl!, filePath);

    await Gal.putVideo(filePath, album: 'Vidflow');

    return filePath;
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final status = Platform.isAndroid
        ? await Permission.videos.request()
        : await Permission.photos.request();

    if (!status.isGranted) {
      throw Exception('Storage permission denied');
    }
  }
}
