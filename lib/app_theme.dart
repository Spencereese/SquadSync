import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Core color palette - high-contrast dark theme with subtle blue accents
  static const primaryColor = Color(0xFF007AFF); // iMessage blue for primary
  static const secondaryColor = Color(0xFF5AC8FA); // Light blue for secondary
  static const accentColor = Color(0xFF007AFF); // Subtle blue accents
  static const errorColor = Color(0xFFFF3B30); // iOS red for errors
  static const hintColor = Color(0xFF8E8E93); // Neutral gray for hints

  // Light/dark specific colors
  static const lightBackgroundColor = Colors.white;
  static const lightTextColor = Colors.black;
  static const darkBackgroundColor = Colors.black; // Pure black for dark mode
  static const darkTextColor = Colors.white;
  static const cardDarkColor = Color(0xFF1C1C1E); // Dark gray for cards
  static const cardLightColor =
      Color(0xFFF2F2F7); // Light gray for light mode cards

  // Common TextTheme - using Google Fonts Roboto for clean typography
  static final commonTextTheme = GoogleFonts.robotoTextTheme().copyWith(
    bodyMedium:
        GoogleFonts.roboto(fontSize: 16.0, fontWeight: FontWeight.normal),
    titleLarge: GoogleFonts.roboto(fontSize: 20.0, fontWeight: FontWeight.bold),
    labelLarge: GoogleFonts.roboto(fontSize: 16.0, fontWeight: FontWeight.w600),
    headlineMedium:
        GoogleFonts.roboto(fontSize: 24.0, fontWeight: FontWeight.bold),
    titleMedium:
        GoogleFonts.roboto(fontSize: 18.0, fontWeight: FontWeight.w600),
    bodySmall: GoogleFonts.roboto(fontSize: 14.0),
    labelSmall: GoogleFonts.roboto(fontSize: 12.0, fontWeight: FontWeight.w500),
    headlineSmall:
        GoogleFonts.roboto(fontSize: 20.0, fontWeight: FontWeight.bold),
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

  // Common CardTheme - minimal elevation for professional look
  static CardThemeData _cardTheme(Color cardColor) {
    return CardThemeData(
      color: cardColor,
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
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

  // Light Theme - Using Material 3 ColorScheme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
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
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: accentColor, width: 2.0),
      ),
      hintStyle: TextStyle(color: hintColor),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );

  // Dark Theme - Default dark mode with high-contrast blacks/grays and subtle blue accents
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
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
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: accentColor, width: 2.0),
      ),
      hintStyle: TextStyle(color: hintColor),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );

  static const darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.black, Color(0xFF1a1a2e)],
  );

  static const lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.white, Color(0xFFF5F5F5)],
  );
}
