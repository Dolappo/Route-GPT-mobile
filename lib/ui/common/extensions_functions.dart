import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension CapExtension on String {
  String capitalize() {
    if (isEmpty) return "";

    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }

  String inCaps() {
    if (isEmpty) return "";

    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String allInCaps() {
    if (isEmpty) return "";

    return toUpperCase();
  }

  String removeFirstCharacter() {
    List ch = split('');
    String word = "";
    ch.removeAt(0);
    for (var element in ch) {
      word += element;
    }
    return word;
  }

  String capitalizeFirstofEach() {
    if (isEmpty) return "";

    var temp = split(" ");
    if (temp.length < 2) return capitalize();

    return temp.map((str) => str.capitalize).join(" ");
  }
}

extension DateOnly on String {
  String get formattedDate {
    // Split the string by space and take the first part
    return split(' ')[0];
  }
}

extension DateTimeExtension on DateTime {
  String get greetings {
    var hour = this.hour;
    if (hour < 12) {
      return 'Good Morning!';
    }
    if (hour < 17) {
      return 'Good Afternoon!';
    }
    return 'Good Evening!';
  }
}

//// Theme extension
extension ThemeExtension on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  // ElevatedButtonThemeData get buttonTheme => Theme.of(this).elevatedButtonTheme;
  // OutlinedButtonThemeData get outlinedButton =>
  //     Theme.of(this).outlinedButtonTheme;
  // InputDecorationTheme get textFieldTheme =>
  //     Theme.of(this).inputDecorationTheme;
  // TabBarTheme get tabBarTheme => Theme.of(this).tabBarTheme;
  // ChipThemeData get chipTheme => Theme.of(this).chipTheme;
  // AppBarTheme get appBarTheme => Theme.of(this).appBarTheme;
  // BottomNavigationBarThemeData get bottomNavBarTheme =>
  //     Theme.of(this).bottomNavigationBarTheme;
}

extension AssetName on String {
  String get svg => 'assets/svgs/$this.svg';
  String get png => 'assets/images/$this.png';
  String get jpg => 'assets/images/$this.jpg';
  String get mp4 => 'assets/videos/$this.mp4';
  String get gif => 'assets/gifs/$this.gif';
  String get lottie => 'assets/lotties/$this.json';
  String get webp => 'assets/images/$this.webp';
}

extension StringExtension on String {
  bool get isNumeric {
    if (isEmpty) {
      return false;
    }
    return double.tryParse(this) != null;
  }
}

extension DateTimeExtensions on DateTime {
  String toCustomString() {
    // Format the date as dd/MM/yyyy and time as hh:mm a
    String date = DateFormat('dd/MM/yyyy').format(this);
    String time = DateFormat('hh:mm a').format(this);

    return '$date - $time';
  }

  String toServerDateTimeFormat() {
    try {
      return DateFormat("yyyy-MM-dd HH:mm:ss").format(this);
    } catch (e) {
      throw const FormatException(
          "Invalid date format: Expected dd-MM-yyyy HH:mm");
    }
  }

  String toAmPm() {
    return DateFormat('h:mm a').format(this);
  }

  String toCustomDateFormat() {
    return "${day.toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-${year.toString()}";
  }

  String toDateCommaTimeFormat() {
    return "${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/${year.toString()}, ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
  }

  String toFormattedString() {
    final dateFormat = DateFormat("d MMM, yyyy");
    return dateFormat.format(this);
  }

  // Method to subtract one hour from the current time
  DateTime oneHourBefore() {
    return subtract(const Duration(hours: 1));
  }
}
