import 'package:flutter/material.dart';

class FoodMelaaColors {
  FoodMelaaColors._();

  // ── Rider Emerald Theme ──────────────────────────────────────────
  static const Color riderPrimary = Color(0xFF047857);
  static const Color riderPrimaryDark = Color(0xFF065F46);
  static const Color riderPrimaryLight = Color(0xFFECFDF5);
  static const Color riderAccent = Color(0xFF10B981);

  // ── Customer Orange (for category badges) ────────────────────────
  static const Color primary = Color(0xFFF15A24);
  static const Color primaryDark = Color(0xFFE54A15);
  static const Color primaryLight = Color(0xFFFFF0EC);
  static const Color primaryExtraLight = Color(0xFFFFF6F3);

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFFF9E6);
  static const Color vegGreen = Color(0xFF24963F);
  static const Color nonVegRed = Color(0xFFE23744);
  static const Color ratingGreen = Color(0xFF24963F);

  // ── Backgrounds ──────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ── Text ─────────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textGrey = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color borderGrey = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF1F5F9);

  // ── Status ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Category Colors ──────────────────────────────────────────────
  static const Map<String, Color> categoryColors = {
    'grocery': Color(0xFF7C3AED),
    'vegetables': Color(0xFF059669),
    'fruits': Color(0xFFEA580C),
    'dairy': Color(0xFF0284C7),
    'eggs_meat': Color(0xFFDC2626),
    'cooked_food': Color(0xFFF15A24),
    'non_veg': Color(0xFFBE123C),
    'sweets': Color(0xFFDB2777),
    'snacks': Color(0xFFD97706),
    'mixed': Color(0xFF475569),
    'general': Color(0xFF64748B),
  };

  static Color categoryColor(String key) => categoryColors[key.toLowerCase()] ?? const Color(0xFF64748B);
}
