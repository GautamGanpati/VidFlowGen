import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vidflow/core/constants/app_colors.dart';
import 'package:vidflow/models/generated_video.dart';
import 'package:vidflow/widgets/expiry_badge.dart';

class VideoGridTile extends StatelessWidget {
  const VideoGridTile({
    super.key,
    required this.video,
    required this.onTap,
  });

  final GeneratedVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video.thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: video.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.surfaceLight),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            else
              _placeholder(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: ExpiryBadge(expiresAt: video.expiresAt),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusChip(status: video.status),
                  const SizedBox(height: 6),
                  Text(
                    video.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(
          Icons.videocam_rounded,
          color: AppColors.textSecondary,
          size: 36,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final VideoStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      VideoStatus.completed => AppColors.success,
      VideoStatus.processing || VideoStatus.pending => AppColors.accent,
      VideoStatus.failed => AppColors.error,
      VideoStatus.expired => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
