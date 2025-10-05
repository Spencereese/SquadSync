import 'package:flutter/material.dart';

class AppTheme {
  // Core color palette - these are static and shared across themes
  static const primaryColor =
      Color(0xFF1A237E); // Deep indigo for primary elements
  static const secondaryColor =
      Color(0xFF3F51B5); // Lighter indigo for secondary accents
  static const accentColor =
      Colors.cyanAccent; // Bright cyan for highlights and calls-to-action
  static const errorColor =
      Colors.redAccent; // Red for errors and destructive actions like logout
  static const hintColor =
      Colors.grey; // Neutral grey for hints and placeholders

  // Light/dark specific colors
  static const lightBackgroundColor = Colors.white;
  static const lightTextColor = Colors.black;
  static const darkBackgroundColor = Colors
      .transparent; // Transparent for dark mode (assuming custom background)
  static const darkTextColor = Colors.white;
  static const cardDarkColor =
      Color(0xFF121212); // Slightly darker card for dark mode
  static const cardLightColor =
      Color(0xFFE0E0E0); // Light grey for cards in light mode

  // Common TextTheme - applied to both light and dark, with color overrides where needed
  static const commonTextTheme = TextTheme(
    bodyMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.normal),
    titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
    labelLarge:
        TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600), // Button text
    headlineMedium: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
    // Added more styles for completeness (e.g., for subtitles, captions)
    titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600),
    bodySmall: TextStyle(fontSize: 14.0),
    labelSmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500),
    headlineSmall: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
  );

  // Common BottomNavigationBarThemeData - shared logic with color overrides
  static BottomNavigationBarThemeData _bottomNavTheme(
      Color selectedColor, Color unselectedColor, Color backgroundColor) {
    return BottomNavigationBarThemeData(
      backgroundColor: backgroundColor,
      selectedItemColor: selectedColor,
      unselectedItemColor: unselectedColor,
      selectedLabelStyle:
          const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontSize: 12.0),
      showUnselectedLabels: true,
      selectedIconTheme: IconThemeData(color: selectedColor, size: 24.0),
      unselectedIconTheme: IconThemeData(color: unselectedColor, size: 24.0),
    );
  }

  // Common SliderThemeData - shared across themes
  static const commonSliderTheme = SliderThemeData(
    activeTrackColor: accentColor,
    inactiveTrackColor: Colors.grey,
    thumbColor: accentColor,
    overlayColor: accentColor,
    valueIndicatorColor: accentColor,
    valueIndicatorTextStyle: TextStyle(color: Colors.black),
  );

  // Common ElevatedButtonThemeData - for consistency (e.g., logout button)
  static ElevatedButtonThemeData _elevatedButtonTheme(Color foregroundColor) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: errorColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
    );
  }

  // Common CardTheme - with color override
  static CardThemeData _cardTheme(Color cardColor) {
    return CardThemeData(
      color: cardColor,
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: accentColor.withAlpha(76), width: 1.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    );
  }

  // Common AppBarTheme - with background and foreground overrides
  static AppBarTheme _appBarTheme(
      Color backgroundColor, Color foregroundColor) {
    return AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0.0,
    );
  }

  // Light Theme - Using Material 3 ColorScheme for better harmony and future-proofing
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true, // Enable Material 3 for improved design system
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor, // Using tertiary for accents like cyan
      error: errorColor,
      surface: cardLightColor,
      onSurface: lightTextColor,
    ),
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBackgroundColor,
    appBarTheme: _appBarTheme(lightBackgroundColor, accentColor),
    elevatedButtonTheme: _elevatedButtonTheme(lightTextColor),
    cardTheme: _cardTheme(cardLightColor),
    textTheme: commonTextTheme.apply(
      bodyColor: lightTextColor,
      displayColor: lightTextColor,
    ),
    bottomNavigationBarTheme:
        _bottomNavTheme(accentColor, Colors.grey[600]!, lightBackgroundColor),
    sliderTheme: commonSliderTheme,
    // Additional Material 3 tweaks: Input decoration for forms/chat inputs
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: accentColor, width: 2.0),
      ),
      hintStyle: TextStyle(color: hintColor),
    ),
  );

  // Dark Theme - Mirroring light with dark-specific colors
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true, // Enable Material 3
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      error: errorColor,
      surface: cardDarkColor,
      onSurface: darkTextColor,
    ),
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackgroundColor,
    appBarTheme: _appBarTheme(Colors.black, accentColor),
    elevatedButtonTheme: _elevatedButtonTheme(darkTextColor),
    cardTheme: _cardTheme(cardDarkColor),
    textTheme: commonTextTheme.apply(
      bodyColor: darkTextColor,
      displayColor: darkTextColor,
    ),
    bottomNavigationBarTheme:
        _bottomNavTheme(accentColor, Colors.grey[600]!, Colors.black),
    sliderTheme: commonSliderTheme,
    // Matching input decoration for dark mode
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: accentColor, width: 2.0),
      ),
      hintStyle: TextStyle(color: hintColor),
    ),
  );
}
