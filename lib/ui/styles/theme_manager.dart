import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stacked/stacked.dart';

import '../../services/local_storage_service.dart';
import 'color.dart';
import 'dimension.dart';
import 'texts.dart';

class ThemeNotifier with ListenableServiceMixin {
  late ThemeData _themeData;
  ThemeMode _themeMode = defaultThemeMode;

  static const ThemeMode defaultThemeMode = ThemeMode.system;
  static ThemeNotifier? _instance;

  static ThemeNotifier get getInstance {
    _instance ??= ThemeNotifier._();
    return _instance!;
  }

  ThemeNotifier._() {
    _themeData = darkTheme; // or a fallbackTheme of your choice
    LocalStorageService().readValue('themeMode').then((value) {
      var themeMode = value ?? defaultThemeMode.name;
      if (themeMode == 'dark') {
        setDarkMode();
      } else if (themeMode == 'light') {
        setLightMode();
      } else {
        setSystemMode();
      }
      notifyListeners();
    });
  }

  // === Helpers for dynamic access ===
  TextStyles get textStyles => TextStyles(this);
  AppColor get colors => AppColor(this);
  Dimen get dimens => Dimen(this);

  // === Getters ===
  ThemeData getTheme() => _themeData;
  ThemeMode get themeMode => _themeMode;
  bool get isInLightMode => _themeMode == ThemeMode.light;

  // // === Initialize saved theme ===
  // Future<void> _initTheme() async {
  //   final storedValue = await LocalStorageService().readValue('themeMode');
  //   final themeModeName = storedValue ?? defaultThemeMode.name;
  //   if (kDebugMode) {
  //     print("Theme Mode Name: $themeModeName");
  //   }
  //   switch (themeModeName) {
  //     case 'dark':
  //       setDarkMode();
  //       break;
  //     case 'light':
  //       setLightMode();
  //       break;
  //     default:
  //       setSystemMode();
  //       break;
  //   }
  //   notifyListeners();
  // }

  // === Light Theme Definition ===
  ThemeData get lightTheme => ThemeData(
        primarySwatch: AppColor.primarySwatch,
        primaryColor: AppColor.lightPrimaryColor,
        scaffoldBackgroundColor: AppColor.lightBackgroundColor,
        fontFamily: TextStyles.fontFamily,
        colorScheme: const ColorScheme.light(
          primary: AppColor.lightPrimaryColor,
          secondary: AppColor.lightSecondaryColor,
          background: AppColor.lightBackgroundColor,
          onPrimary: Colors.white,
        ),
        dividerColor: AppColor.lightDividerColor,
        cardColor: AppColor.lightCardColor,
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          color: Colors.transparent,
          titleTextStyle: textStyles.displaySmall.copyWith(
            color: AppColor.lightPrimaryTextColor,
          ),
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: textStyles.textTheme.apply(
          bodyColor: AppColor.lightPrimaryTextColor,
          displayColor: AppColor.lightPrimaryTextColor,
        ),
        useMaterial3: true,
      );

  // === Dark Theme Definition ===
  ThemeData get darkTheme => ThemeData(
        primarySwatch: AppColor.primarySwatch,
        primaryColor: AppColor.darkPrimaryColor,
        scaffoldBackgroundColor: AppColor.darkBackgroundColor,
        fontFamily: TextStyles.fontFamily,
        colorScheme: const ColorScheme.dark(
          primary: AppColor.darkPrimaryColor,
          secondary: AppColor.darkSecondaryColor,
          onPrimary: Colors.white,
        ),
        dividerColor: AppColor.darkDividerColor,
        cardColor: AppColor.darkCardColor,
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
          color: Colors.transparent,
          titleTextStyle: textStyles.displayLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColor.darkPrimaryTextColor,
          ),
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: textStyles.textTheme.apply(
          bodyColor: AppColor.darkPrimaryTextColor,
          displayColor: AppColor.darkPrimaryTextColor,
        ),
        useMaterial3: true,
      );

  // === Mode Setters ===
  void setLightMode() async {
    if (kDebugMode) {
      print("Mode");
    }
    _themeData = lightTheme;
    _themeMode = ThemeMode.light;
    notifyListeners();
    if (kDebugMode) {
      print("ThemeMode: ${_themeMode.name}");
    }
    LocalStorageService().storeValue('themeMode', ThemeMode.light.name);
  }

  void setDarkMode() async {
    _themeData = darkTheme;
    notifyListeners();
    _themeMode = ThemeMode.dark;
    LocalStorageService().storeValue('themeMode', ThemeMode.dark.name);
    notifyListeners();
  }

  void setSystemMode() async {
    _themeMode = ThemeMode.system;
    await LocalStorageService().storeValue('themeMode', ThemeMode.system.name);
    notifyListeners();
  }

  void switchMode() {
    isInLightMode ? setDarkMode() : setLightMode();
    notifyListeners();
  }
}

extension Conv on ThemeMode {
  String string() {
    return toString().split('.').last;
  }
}

extension Con on String {
  ThemeMode toEnum() {
    for (ThemeMode type in ThemeMode.values) {
      if (type.string() == this) return type;
    }
    return ThemeMode.light;
  }
}
