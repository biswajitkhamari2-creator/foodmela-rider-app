import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Palette - Vibrant Warm Orange (FoodTrack Signature)
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8C5E);
  static const Color primaryDark = Color(0xFFE55A2B);

  // Secondary Palette - Deep Teal
  static const Color secondary = Color(0xFF0D7377);
  static const Color secondaryLight = Color(0xFF14A3A8);
  static const Color secondaryDark = Color(0xFF0A5558);

  // Accent
  static const Color accent = Color(0xFFFFD166);
  static const Color accentLight = Color(0xFFFFE6A0);

  // Backgrounds
  static const Color background = Color(0xFFFAFAFA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F6FA);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C6C80);
  static const Color textTertiary = Color(0xFF9E9EB5);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);

  // Veg / Non-Veg Indicators
  static const Color vegGreen = Color(0xFF27AE60);
  static const Color nonVegRed = Color(0xFFC0392B);

  // Bottom Navigation
  static const Color navSelected = Color(0xFFFF6B35);
  static const Color navUnselected = Color(0xFFB0B0C3);

  // Shimmer / Skeleton loading
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFFFF6B35),
    Color(0xFFFF4A1A),
  ];
  static const List<Color> splashGradient = [
    Color(0xFFFF6B35),
    Color(0xFF0D7377),
  ];
  static const List<Color> darkGradient = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];
}
