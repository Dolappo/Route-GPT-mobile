import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color.dart';
import 'theme_manager.dart';

final String fontFamily2 =
    GoogleFonts.montserrat().fontFamily ?? "Helvetica, Arial, serif";
final String display =
    GoogleFonts.audiowide().fontFamily ?? "Helvetica, Arial, serif";

TextStyle _displayLarge = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    color: Colors.white
    // height: 36 / 28,
    );

TextStyle _displayMedium = TextStyle(
  fontFamily: display,
  fontWeight: FontWeight.w600,
  fontSize: 20,
);

/// Slightly bold but larger
TextStyle _displaySmall = TextStyle(
  fontFamily: display,
  fontWeight: FontWeight.w500,
  fontSize: 24,
);

/// Slightly bold... Use for toolbars.
TextStyle _headlineMedium = TextStyle(
  fontFamily: fontFamily2,
  fontWeight: FontWeight.w600,
  fontSize: 16,
  height: 24 / 16,
);

TextStyle _headlineSmall = TextStyle(
  fontFamily: fontFamily2,
  fontWeight: FontWeight.w500,
  fontSize: 16,
);

TextStyle _titleLarge = TextStyle(
  fontFamily: display,
  fontWeight: FontWeight.w600,
  fontSize: 20,
  height: 20 / 20,
);

TextStyle _titleMedium = TextStyle(
  fontFamily: fontFamily2,
  fontWeight: FontWeight.w600,
  fontSize: 16,
  height: 21 / 14,
);

TextStyle _titleSmall = TextStyle(
  fontFamily: fontFamily2,
  fontWeight: FontWeight.w600,
  fontSize: 14,
);

TextStyle _bodyLarge = TextStyle(
  fontFamily: fontFamily2,
  fontWeight: FontWeight.w400,
  fontSize: 18,
);

TextStyle _bodyMedium = TextStyle(
  fontFamily: fontFamily2,
  fontWeight: FontWeight.w400,
  fontSize: 16,
  height: 18 / 16,
);

TextStyle _bodySmall = TextStyle(
  fontFamily: fontFamily2,
  fontWeight: FontWeight.w400,
  fontSize: 14,
);

TextStyle _labelLarge = TextStyle(
  fontFamily: fontFamily2,
  fontWeight: FontWeight.w800,
  fontSize: 16,
  height: 24 / 16,
);

class TextStyles {
  static String fontFamily = fontFamily2;

  ThemeMode currentMode = ThemeNotifier.defaultThemeMode;
  late AppColor colors;

  TextStyles(ThemeNotifier themeNotifier) {
    currentMode = themeNotifier.themeMode;
    colors = themeNotifier.colors;
  }

  TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
      );

  TextStyle get displayLarge =>
      _displayLarge.copyWith(color: colors.primaryTextColor);
  TextStyle get displayMedium =>
      _displayMedium.copyWith(color: colors.primaryTextColor);
  TextStyle get displaySmall =>
      _displaySmall.copyWith(color: colors.primaryTextColor);

  TextStyle get headlineMedium =>
      _headlineMedium.copyWith(color: colors.primaryTextColor);
  TextStyle get headlineSmall =>
      _headlineSmall.copyWith(color: colors.primaryTextColor);

  TextStyle get titleLarge =>
      _titleLarge.copyWith(color: colors.primaryTextColor);
  TextStyle get titleMedium =>
      _titleMedium.copyWith(color: colors.primaryTextColor);
  TextStyle get titleSmall =>
      _titleSmall.copyWith(color: colors.primaryTextColor);

  TextStyle get bodyLarge =>
      _bodyLarge.copyWith(color: colors.primaryTextColor);
  TextStyle get bodyMedium =>
      _bodyMedium.copyWith(color: colors.primaryTextColor);
  TextStyle get bodySmall =>
      _bodySmall.copyWith(color: colors.primaryTextColor);

  TextStyle get labelLarge =>
      _labelLarge.copyWith(color: colors.primaryTextColor);
}
