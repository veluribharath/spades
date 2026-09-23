import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Quiet table, bright cards": a near-black felt that recedes, ivory
/// cards that carry all the color, and one brass accent that only ever
/// means "you can act now". Source of truth: the Spades Design Language
/// canvas (Foundations board).
class AppColors {
  AppColors._();

  /// Table ground.
  static const felt = Color(0xFF0B1F19);

  /// Raised surfaces: chips, card backs, the vignette's center.
  static const feltRaised = Color(0xFF13302A);
  static const feltHover = Color(0xFF1A3A31);

  /// Card faces and headline text.
  static const ivory = Color(0xFFF4EEE2);

  /// Body text on felt.
  static const text = Color(0xFFECE4D2);

  /// Secondary text on felt.
  static const sage = Color(0xFF9DAA9F);

  /// The only accent: your turn, a playable card, a bid you can place.
  static const brass = Color(0xFFC9A45C);
  static const brassBright = Color(0xFFE0BE78);

  /// Pips: hearts/diamonds and spades/clubs.
  static const garnet = Color(0xFFA23B2E);
  static const ink = Color(0xFF1C1B19);

  /// Negative score deltas.
  static const loss = Color(0xFFD98A7E);

  static const hairline = Color(0x1AECE4D2);
  static const hairlineStrong = Color(0x38ECE4D2);
  static const tint = Color(0x0FECE4D2);
}

/// Two faces: Cormorant Garamond for display, scores and card indices;
/// Instrument Sans for everything else.
class AppText {
  AppText._();

  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ivory,
    FontStyle? style,
    double height = 1.0,
  }) => GoogleFonts.cormorantGaramond(
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontStyle: style,
    height: height,
  );

  static TextStyle ui({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? height,
  }) => GoogleFonts.instrumentSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  /// Small caps-style labels: 11px, 600, +0.2em tracking.
  static TextStyle label({Color color = AppColors.sage, double size = 11}) =>
      GoogleFonts.instrumentSans(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: size * 0.2,
        color: color,
      );
}

class AppMotion {
  AppMotion._();

  /// Lift, hover, chip press.
  static const quick = Duration(milliseconds: 180);

  /// A card travelling to the trick.
  static const flight = Duration(milliseconds: 320);
}

/// The felt with a whisper of vignette.
BoxDecoration feltTableDecoration() => const BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, -0.1),
    radius: 1.1,
    colors: [AppColors.feltRaised, AppColors.felt],
    stops: [0.0, 0.65],
  ),
);

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.felt,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.brass,
      onPrimary: AppColors.ink,
      secondary: AppColors.text,
      surface: AppColors.felt,
      onSurface: AppColors.text,
    ),
    textTheme: GoogleFonts.instrumentSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.ivory),
    dividerColor: AppColors.hairline,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brass,
        foregroundColor: AppColors.ink,
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        textStyle: AppText.ui(size: 16, weight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        side: const BorderSide(color: AppColors.hairlineStrong),
        textStyle: AppText.ui(size: 15, weight: FontWeight.w500),
        shape: const StadiumBorder(),
      ),
    ),
  );
}
