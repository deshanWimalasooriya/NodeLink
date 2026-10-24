import 'package:flutter/material.dart';

class AppTheme {
  // Primary Cyber Palette
  static const Color deepNavy = Color(0xFF0B132B);
  static const Color spaceIndigo = Color(0xFF1C2541);
  static const Color surfaceDark = Color(0xFF111A33);
  static const Color surfaceCard = Color(0x991C2541);
  static const Color surfaceCardLight = Color(0xCC1A264F);

  // Vibrant Cyber Accents
  static const Color electricCyan = Color(0xFF00F0FF);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color cyberTeal = Color(0xFF05D5EB);
  static const Color cyberBlue = Color(0xFF1F8EFA);
  static const Color warningRed = Color(0xFFFF3B5C);
  static const Color offlineGrey = Color(0xFF6B7280);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E9DB8);
  static const Color textMuted = Color(0xFF5F6E8A);

  // Light Mode Palette (Faithfully aligned with mockups in Interfaces/UI/light mode/)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightCardBg = Color(0xF5FFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Cyber Box Shadows & Glows
  static List<BoxShadow> cyanGlow({double blur = 16, double spread = 0, double opacity = 0.4}) => [
    BoxShadow(
      color: electricCyan.withValues(alpha: opacity),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];

  static List<BoxShadow> neonGlow({double blur = 16, double spread = 0, double opacity = 0.4}) => [
    BoxShadow(
      color: neonGreen.withValues(alpha: opacity),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> lightCardShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  // Theme Data Configuration - Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deepNavy,
      primaryColor: electricCyan,
      canvasColor: deepNavy,
      cardColor: spaceIndigo,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: electricCyan,
        secondary: neonGreen,
        surface: surfaceDark,
        error: warningRed,
        onPrimary: deepNavy,
        onSecondary: deepNavy,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: electricCyan,
          foregroundColor: deepNavy,
          elevation: 6,
          shadowColor: electricCyan.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return neonGreen;
          }
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return neonGreen.withValues(alpha: 0.35);
          }
          return spaceIndigo;
        }),
      ),
    );
  }

  // Theme Data Configuration - Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: electricCyan,
      canvasColor: lightBg,
      cardColor: lightSurface,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.light(
        primary: electricCyan,
        secondary: cyberTeal,
        surface: lightSurface,
        error: warningRed,
        onPrimary: deepNavy,
        onSecondary: deepNavy,
        onSurface: lightTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: electricCyan,
          foregroundColor: deepNavy,
          elevation: 4,
          shadowColor: electricCyan.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return lightTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return electricCyan;
          }
          return lightBorder;
        }),
      ),
    );
  }
}
