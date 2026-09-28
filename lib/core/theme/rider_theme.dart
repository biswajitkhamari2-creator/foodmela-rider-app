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
      surface: FoodMelaaColors.background,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: FoodMelaaColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: FoodMelaaColors.riderPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: FoodMelaaColors.riderPrimaryDark.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: FoodMelaaColors.borderLight, width: 1),
        ),
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
          borderSide: const BorderSide(color: FoodMelaaColors.borderLight, width: 1),
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
            color: FoodMelaaColors.riderPrimaryDark),
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
    const gold = FoodMelaaColors.riderAccent;
    final scheme = ColorScheme.fromSeed(
      seedColor: FoodMelaaColors.riderPrimary,
      brightness: Brightness.dark,
      primary: gold,
      onPrimary: const Color(0xFF1C1813),
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
        foregroundColor: gold,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: gold),
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
          backgroundColor: gold,
          foregroundColor: const Color(0xFF1C1813),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: gold, width: 1.2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gold,
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
          borderSide: const BorderSide(color: gold, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: gold.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w700, color: gold),
        side: BorderSide(color: gold.withValues(alpha: 0.3)),
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
                ? gold
                : FoodMelaaColors.riderDarkTextSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? gold.withValues(alpha: 0.3)
                : FoodMelaaColors.riderDarkBorder),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: gold,
        textColor: FoodMelaaColors.riderDarkText,
      ),
    );
  }
}
