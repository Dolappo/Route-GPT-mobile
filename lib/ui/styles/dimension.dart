import 'package:flutter/material.dart';

import 'theme_manager.dart';

class Dimen {
  static final BorderRadius primaryBorderRadius = BorderRadius.circular(6.0);
  static const double defaultIntraColumnSpacing = 8.0;
  static const double roundButtonRadius = 30.0;
  static const double bottomSheetCornerRadius = 36.0;
  static const double roundedFieldRadius = 40.0;

  // FontSizes
  static const double bodyTextSize = 16.0;

  // spacing
  static const double smallHeight = 8;
  static const double smallWidth = 8;
  static const double mediumHeight = 16;
  static const double mediumWeight = 16;
  static const double bigHeight = 32;
  static const double bigWidth = 32;
  static const double largeHeight = 50;
  static const double largeWidth = 50;
  static const double buttonHeight = 60;

  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;

  // Constants

  static const EdgeInsets bodyPadding = EdgeInsets.all(16);

  ThemeData theme = ThemeData();

  Dimen(ThemeNotifier themeNotifier) {
    theme = themeNotifier.getTheme();
  }
}
