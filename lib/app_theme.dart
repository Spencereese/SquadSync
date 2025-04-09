import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF1A237E);
  static const secondaryColor = Color(0xFF3F51B5);
  static const accentColor = Colors.cyanAccent;
  static const backgroundColor = Color.fromRGBO(66, 66, 66, 0.9);
  static const textColor = Colors.white;
  static const hintColor = Colors.grey;
  static const errorColor = Colors.redAccent;

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.indigo,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: accentColor,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: errorColor, // For logout button
        foregroundColor: textColor,
        padding: EdgeInsets.symmetric(vertical: 12.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // Removed textStyle to rely on textTheme
      ),
    ),
    cardTheme: CardTheme(
      color: Colors.grey[900]!,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withAlpha(76), width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: textColor, fontSize: 16),
      titleLarge: TextStyle(
          color: accentColor, fontSize: 20, fontWeight: FontWeight.bold),
      labelLarge: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w600), // For button text
      headlineMedium: TextStyle(
          color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.black,
      selectedItemColor: accentColor,
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      showUnselectedLabels: true,
      selectedIconTheme: const IconThemeData(color: accentColor, size: 24),
      unselectedIconTheme: IconThemeData(color: Colors.grey[600], size: 24),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: accentColor,
      inactiveTrackColor: Colors.grey,
      thumbColor: accentColor,
      overlayColor: accentColor,
      valueIndicatorColor: accentColor,
      valueIndicatorTextStyle: TextStyle(color: Colors.black),
    ),
  );

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.indigo,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: accentColor,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: errorColor, // For logout button
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(vertical: 12.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // Removed textStyle to rely on textTheme
      ),
    ),
    cardTheme: CardTheme(
      color: Colors.grey[100]!,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withAlpha(76), width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.black, fontSize: 16),
      titleLarge: TextStyle(
          color: accentColor, fontSize: 20, fontWeight: FontWeight.bold),
      labelLarge: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w600), // For button text
      headlineMedium: TextStyle(
          color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: accentColor,
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      showUnselectedLabels: true,
      selectedIconTheme: const IconThemeData(color: accentColor, size: 24),
      unselectedIconTheme: IconThemeData(color: Colors.grey[600], size: 24),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: accentColor,
      inactiveTrackColor: Colors.grey,
      thumbColor: accentColor,
      overlayColor: accentColor,
      valueIndicatorColor: accentColor,
      valueIndicatorTextStyle: TextStyle(color: Colors.black),
    ),
  );
}
