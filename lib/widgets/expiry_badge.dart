import 'package:flutter/material.dart';
import 'package:vidflow/core/constants/app_colors.dart';

class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.difference(DateTime.now());
    final isUrgent = remaining.inHours < 24;

    final label = remaining.isNegative
        ? 'Expired'
        : remaining.inDays >= 1
            ? '${remaining.inDays}d left'
            : '${remaining.inHours}h left';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.warning.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent
              ? AppColors.warning.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isUrgent ? AppColors.warning : AppColors.textPrimary,
        ),
      ),
    );
  }
}
