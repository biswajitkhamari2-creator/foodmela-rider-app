import 'package:flutter/material.dart';

/// Premium golden design tokens for the rider app — light + dark aware.
/// Existing FoodMelaaColors / RiderTheme are untouched; screens opt into
/// these tokens. Backend-independent, pure frontend.
class RiderGold {
  RiderGold._();

  // Brand golds
  static const goldDeep = Color(0xFF8C5E00);
  static const gold = Color(0xFFB8860B);
  static const goldBright = Color(0xFFD4AF37);
  static const goldPale = Color(0xFFFFF6E0);
  static const goldBorder = Color(0xFFEAD9A8);
  static const goldWash = Color(0xFFFFFBF2);

  // Ink / muted per brightness
  static const inkLight = Color(0xFF2B2118);
  static const mutedLight = Color(0xFF8A7364);
  static const inkDark = Color(0xFFF5EFE4);
  static const mutedDark = Color(0xFFB8AFA0);
  static const cardDark = Color(0xFF1C1813);
  static const borderDark = Color(0xFF3A3226);
  static const surfaceDark = Color(0xFF12100C);

  static const statusOrange = Color(0xFFE07B00);
  static const statusBlue = Color(0xFF2563EB);
  static const statusPurple = Color(0xFF7C3AED);
  static const statusGreen = Color(0xFF15803D);
  static const statusRed = Color(0xFFDC2626);

  static Color ink(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? inkDark : inkLight;

  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? mutedDark : mutedLight;

  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? cardDark : Colors.white;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? borderDark : goldBorder;

  static Color scaffold(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceDark : goldWash;

  static LinearGradient headerGradient() => const LinearGradient(
        colors: [goldDeep, goldBright],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static BoxDecoration goldCard(BuildContext context) => BoxDecoration(
        color: card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.06 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );
}

/// Status → pill colors (spec: Placed gold, Preparing orange, Ready blue,
/// Out-for-delivery purple, Delivered green, Cancelled red).
class RiderStatusStyle {
  final String label;
  final Color fg;
  final Color bg;
  const RiderStatusStyle(this.label, this.fg, this.bg);

  static RiderStatusStyle of(String status, int stage) {
    final s = status.toLowerCase();
    if (s.contains('cancel') || stage == -1) {
      return const RiderStatusStyle(
          'Cancelled', RiderGold.statusRed, Color(0xFFFDECEC));
    }
    if (stage == 3 || s.contains('deliver') && s.contains('🏁') ||
        (s.contains('delivered'))) {
      return const RiderStatusStyle(
          'Delivered', RiderGold.statusGreen, Color(0xFFE7F6EC));
    }
    if (s.contains('out for delivery') ||
        s.contains('on the way') ||
        (s.contains('way') && stage == 2)) {
      return const RiderStatusStyle(
          'Out for Delivery', RiderGold.statusPurple, Color(0xFFF1EAFE));
    }
    if (s.contains('ready') ||
        s.contains('pickup') ||
        s.contains('picked')) {
      return const RiderStatusStyle(
          'Ready for Pickup', RiderGold.statusBlue, Color(0xFFE8F0FE));
    }
    if (s.contains('prepar') ||
        s.contains('cook') ||
        s.contains('kitchen') ||
        s.contains('accept')) {
      return const RiderStatusStyle(
          'Preparing', RiderGold.statusOrange, Color(0xFFFFF1DE));
    }
    return const RiderStatusStyle(
        'Order Placed', RiderGold.gold, RiderGold.goldPale);
  }
}
