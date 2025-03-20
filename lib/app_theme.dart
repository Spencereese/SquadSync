import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF1A237E);
  static const secondaryColor = Color(0xFF3F51B5);
  static const accentColor = Colors.cyanAccent;
  static const backgroundColor = Color.fromRGBO(66, 66, 66, 0.9);
  static const textColor = Colors.white;
  static const hintColor = Colors.grey;
  static const errorColor = Colors.redAccent;

  static final ThemeData theme = ThemeData(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: textColor),
      bodySmall: TextStyle(color: hintColor),
    ),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: primaryColor,
      secondary: accentColor,
    ),
  );
}
