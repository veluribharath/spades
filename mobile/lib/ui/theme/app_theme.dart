import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized visual language: a deep emerald felt table, warm gold
/// accents for HUD elements, and a clean numeral typeface — aiming for
/// the same premium, tactile feel as top-shelf digital card-table apps
/// (see docs/PLAN.md §4).
class AppColors {
  AppColors._();

  static const feltDark = Color(0xFF04231A);
  static const feltMid = Color(0xFF0B4B36);
  static const feltLight = Color(0xFF12694A);

  static const gold = Color(0xFFE6C368);
  static const cream = Color(0xFFF7F3E9);

  static const spadeInk = Color(0xFF1B1B22);
  static const heartRed = Color(0xFFC23B3B);

  static const seatHighlight = Color(0xFFFFD873);
}

BoxDecoration feltTableDecoration() => const BoxDecoration(
  gradient: RadialGradient(
    center: Alignment.center,
    radius: 1.2,
    colors: [AppColors.feltLight, AppColors.feltMid, AppColors.feltDark],
    stops: [0.0, 0.55, 1.0],
  ),
);

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.feltDark,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.gold,
      secondary: AppColors.cream,
      surface: AppColors.feltMid,
    ),
    textTheme: GoogleFonts.nunitoTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.cream, displayColor: AppColors.cream),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.spadeInk,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        textStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),
  );
}
