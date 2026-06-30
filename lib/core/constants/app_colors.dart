import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF0A0A40);
  static const surface = Color(0xFF14141C);
  static const surfaceLight = Color(0xFF1E1E2A);
  static const accent = Color(0xFF462882);
  static const accentSecondary = Color(0xFFFF6F08);
  static const accentTertiary = Color(0xFF8C61FF);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9B9BA8);

  static const success = Color(0xFF4ADE80);

  /// Readable on dark surfaces (not the gradient purple used in accentGradient).
  static const warning = Color(0xFFFBBF24);

  /// Readable on dark surfaces.
  static const error = Color(0xFFF87171);

  static const errorContainer = Color(0xFF3B1218);
  static const warningContainer = Color(0xFF2A2210);

  static const homeGradient = [
    Color(0xFF0A0A0F),
    Color(0xFF1A1030),
    Color(0xFF0A0A0F),
  ];

  static const accentGradient = [accent, Color(0xFF8C1EAA), accentSecondary];
}
