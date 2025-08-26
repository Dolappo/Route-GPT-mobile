import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme_manager.dart';

final appColor = AppColor(ThemeNotifier.getInstance);

class AppColor {
  // === Primary Swatch (general MaterialColor swatch) ===
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF5D5FEF,
    <int, Color>{
      50: Color(0xFFEDEEFE),
      100: Color(0xFFD2D3FB),
      200: Color(0xFFB6B8F9),
      300: Color(0xFF9B9DF6),
      400: Color(0xFF8689F4),
      500: Color(0xFF5D5FEF), // Base color
      600: Color(0xFF5657D7),
      700: Color(0xFF4C4DBD),
      800: Color(0xFF4144A3),
      900: Color(0xFF2D307A),
    },
  );

  // === Light Theme Colors ===
  static const Color lightPrimaryColor = Colors.black; // Soft Indigo
  static const Color lightSecondaryColor = Colors.white; // Blush Pink
  static const Color lightAccentColor = Color(0xFFFFD38C); // Golden Apricot
  static const Color lightBackgroundColor = Color(0xFFF9F9FB); // Soft Porcelain
  static const Color lightDividerColor = Color(0xFFE0E0E0);
  static Color lightCardColor = Colors.grey.shade500; // Lavender Gray
  static const Color lightAppBarColor = Color(0xFFF9F9FB);
  static const Color lightPrimaryTextColor = Color(0xFF1F1F1F);
  static const Color lightSecondaryTextColor = Color(0xFF5A5A5A);
  static const Color lightTertiaryTextColor = Color(0xFF9B9B9B);

  // === Dark Theme Colors ===
  static const Color darkPrimaryColor = Colors.white;
  static const Color darkSecondaryColor = Colors.black;
  static const Color darkAccentColor = Color(0xffFFF563);
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkDividerColor = Color(0xFF303030);
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color darkAppBarColor = Color(0xFF1C1C1C);
  static const Color darkPrimaryTextColor = Colors.white;
  static const Color darkSecondaryTextColor = Colors.black;
  static const Color darkTertiaryTextColor = Color(0xFF9B9B9B);
  static const Color error = Colors.red;

  // === Emotion Indicator Colors ===
  static const Color emotionJoy = Color(0xFFFFCD5D);
  static const Color emotionSadness = Color(0xFF8AAAE5);
  static const Color emotionAnger = Color(0xFFFF6B6B);
  static const Color emotionCalm = Color(0xFFA2E3C4);
  static const Color emotionAnxious = Color(0xFFE6A0F0);

  AppColor(ThemeNotifier themeNotifier) {
    _currentMode = themeNotifier.themeMode;
    if (kDebugMode) {
      print("I am the mode: ${_currentMode.name}");
    }
  }

  ThemeMode _currentMode = ThemeNotifier.defaultThemeMode;

  bool get _isLight => _currentMode == ThemeMode.light;

  // === Dynamic Getters ===
  Color get primaryColor => _isLight ? lightPrimaryColor : darkPrimaryColor;
  // Color get primaryCardColor => _isLight ? lightPrimaryColor : darkPrimaryColor;
  Color get secondaryColor =>
      _isLight ? lightSecondaryColor : darkSecondaryColor;
  Color get accentColor => _isLight ? lightAccentColor : darkAccentColor;
  Color get backgroundColor =>
      _isLight ? lightBackgroundColor : darkBackgroundColor;
  Color get dividerColor => _isLight ? lightDividerColor : darkDividerColor;
  Color get cardColor => _isLight ? lightCardColor : darkCardColor;
  Color get appBarColor => _isLight ? lightAppBarColor : darkAppBarColor;
  Color get errorColor => Colors.red;
  Color get successColor => Colors.green.shade700;

  Color get primaryTextColor =>
      _isLight ? lightPrimaryTextColor : darkPrimaryTextColor;
  Color get primaryButtonTextColor =>
      _isLight ? darkPrimaryTextColor : lightPrimaryTextColor;
  Color get secondaryTextColor =>
      _isLight ? lightSecondaryTextColor : darkSecondaryTextColor;
  Color get secondaryButtonTextColor =>
      _isLight ? darkSecondaryTextColor : lightSecondaryTextColor;
  Color get tertiaryTextColor =>
      _isLight ? lightTertiaryTextColor : darkTertiaryTextColor;
}
