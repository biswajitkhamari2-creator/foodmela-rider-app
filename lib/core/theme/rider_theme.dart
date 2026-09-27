import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'food_melaa_colors.dart';

/// Rider app Material3 themes — light keeps the existing look, dark is a
/// proper dark design built on the riderDark* tokens.
class RiderTheme {
  RiderTheme._();

  static const _radius = 14.0;

  static ThemeData light() {
    const seed = FoodMelaaColors.riderPrimary;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: FoodMelaaColors.riderPrimary,
      secondary: FoodMelaaColors.primary,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: FoodMelaaColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: FoodMelaaColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: FoodMelaaColors.textDark),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FoodMelaaColors.riderPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FoodMelaaColors.riderPrimary,
          side: const BorderSide(
              color: FoodMelaaColors.riderPrimary, width: 1.2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FoodMelaaColors.riderPrimary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: GoogleFonts.inter(color: FoodMelaaColors.textGrey),
        labelStyle: GoogleFonts.inter(color: FoodMelaaColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(
              color: FoodMelaaColors.riderPrimary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: FoodMelaaColors.riderPrimaryLight,
        labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FoodMelaaColors.riderPrimary),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(
        color: FoodMelaaColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? FoodMelaaColors.riderPrimary
                : FoodMelaaColors.textGrey),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? FoodMelaaColors.riderPrimaryLight
                : Colors.grey.shade300),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: FoodMelaaColors.riderPrimary,
        textColor: FoodMelaaColors.textDark,
      ),
    );
  }

  static ThemeData dark() {
    const emerald = Color(0xFF34D399); // brightened for dark contrast
    const gold = Color(0xFFE8C547);
    final scheme = ColorScheme.fromSeed(
      seedColor: FoodMelaaColors.riderPrimary,
      brightness: Brightness.dark,
      primary: emerald,
      onPrimary: const Color(0xFF06281D),
      secondary: gold,
      surface: FoodMelaaColors.riderDarkCard,
      onSurface: FoodMelaaColors.riderDarkText,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: FoodMelaaColors.riderDarkSurface,
      appBarTheme: AppBarTheme(
        backgroundColor: FoodMelaaColors.riderDarkCard,
        foregroundColor: FoodMelaaColors.riderDarkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: FoodMelaaColors.riderDarkText),
      ),
      cardTheme: CardThemeData(
        color: FoodMelaaColors.riderDarkCard,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: FoodMelaaColors.riderDarkBorder),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: const Color(0xFF06281D),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: emerald,
          side: const BorderSide(color: emerald, width: 1.2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: emerald,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FoodMelaaColors.riderDarkCard,
        hintStyle: GoogleFonts.inter(
            color: FoodMelaaColors.riderDarkTextSecondary),
        labelStyle: GoogleFonts.inter(
            color: FoodMelaaColors.riderDarkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(
              color: FoodMelaaColors.riderDarkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: emerald, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: emerald.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w700, color: emerald),
        side: BorderSide(color: emerald.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(
        color: FoodMelaaColors.riderDarkBorder,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FoodMelaaColors.riderDarkCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FoodMelaaColors.riderDarkCard,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FoodMelaaColors.riderDarkCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? emerald
                : FoodMelaaColors.riderDarkTextSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? emerald.withValues(alpha: 0.3)
                : FoodMelaaColors.riderDarkBorder),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: emerald,
        textColor: FoodMelaaColors.riderDarkText,
      ),
    );
  }
}
