import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ObsidianTheme {
  // Colors from Stitch "Obsidian Audio" Design System
  static const Color surface = Color(0xFF0E131E);
  static const Color surfaceDim = Color(0xFF0E131E);
  static const Color surfaceBright = Color(0xFF343945);
  static const Color surfaceContainerLowest = Color(0xFF090E19);
  static const Color surfaceContainerLow = Color(0xFF171B27);
  static const Color surfaceContainer = Color(0xFF1B202B);
  static const Color surfaceContainerHigh = Color(0xFF252A36);
  static const Color surfaceContainerHighest = Color(0xFF303541);
  static const Color surfaceVariant = Color(0xFF303541);

  static const Color onSurface = Color(0xFFDEE2F2);
  static const Color onSurfaceVariant = Color(0xFFCBC3D7);
  static const Color outline = Color(0xFF958EA0);
  static const Color outlineVariant = Color(0xFF494454);

  static const Color primary = Color(0xFFD0BCFF);
  static const Color onPrimary = Color(0xFF3C0091);
  static const Color primaryContainer = Color(0xFFA078FF);
  static const Color onPrimaryContainer = Color(0xFF340080);
  static const Color onPrimaryFixedVariant = Color(0xFF5516BE);

  static const Color secondary = Color(0xFFCEBDFF);
  static const Color onSecondary = Color(0xFF381385);
  static const Color secondaryContainer = Color(0xFF4F319C);
  static const Color onSecondaryContainer = Color(0xFFBEA8FF);

  static const Color tertiary = Color(0xFFD3BBFF);
  static const Color tertiaryContainer = Color(0xFFA37AF1);

  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // Functional Telemetry
  static const Color signalOnline = Color(0xFFFAC811); // Amarillo contrastante para éxito/enlazado
  static const Color signalWarning = Color(0xFF31AEE8); // Azul complementario para negociando/buscando
  static const Color signalClip = Color(0xFFEF4444);

  // Typography Styles
  static TextStyle headlineXl({Color color = onSurface}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 34 / 28,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle headlineLg({Color color = onSurface}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 30 / 24,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle headlineSm({
    Color color = onSurface,
    FontWeight fontWeight = FontWeight.w600,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: fontWeight,
        height: 24 / 18,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle bodyLg({
    Color color = onSurface,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: fontWeight,
        height: 24 / 16,
        color: color,
      );

  static TextStyle bodyMd({
    Color color = onSurface,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: fontWeight,
        height: 20 / 14,
        color: color,
      );

  static TextStyle bodySm({
    Color color = onSurfaceVariant,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: fontWeight,
        height: 16 / 12,
        color: color,
      );

  static TextStyle labelLg({
    Color color = onSurface,
    FontWeight fontWeight = FontWeight.w500,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: fontWeight,
        height: 16 / 13,
        letterSpacing: 0.25,
        color: color,
      );

  static TextStyle labelMd({
    Color color = onSurface,
    FontWeight fontWeight = FontWeight.w500,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: fontWeight,
        height: 14 / 11,
        letterSpacing: 0.5,
        color: color,
      );

  static TextStyle labelSm({
    Color color = onSurfaceVariant,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0.7,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 9.5,
        fontWeight: fontWeight,
        height: 12 / 9.5,
        letterSpacing: letterSpacing,
        color: color,
      );

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
    );
  }
}
