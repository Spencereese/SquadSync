import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SquadSync 2026 Material 3 Theme System
/// Features dynamic color schemes based on game cover art,
/// glassmorphic UI elements, and neon glow effects
class AppTheme {
  // Base colors
  static const Color _darkBackground = Color(0xFF0B0E14);
  static const Color _darkSurface = Color(0xFF14181F);
  static const Color _defaultNeon = Color(0xFF00F5FF); // Cyan neon default

  /// Creates a dark theme with dynamic color seed from game cover art
  ///
  /// [dynamicSeedColor] - Color extracted from IGDB cover art to generate
  /// the dynamic color scheme. Defaults to cyan neon if not provided.
  static ThemeData dark({Color? dynamicSeedColor}) {
    final seedColor = dynamicSeedColor ?? _defaultNeon;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      background: _darkBackground,
      surface: _darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkBackground,

      // Custom text theme with Orbitron for headings, Inter for body
      textTheme: _buildTextTheme(colorScheme),

      // Custom input decoration with glass style
      inputDecorationTheme: _buildInputDecorationTheme(colorScheme),

      // Elevated button with glass fill and neon border
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),

      // Card theme with glass effect
      cardTheme: _buildCardTheme(colorScheme),

      // App bar with glass background
      appBarTheme: _buildAppBarTheme(colorScheme),

      // Bottom navigation with glass effect
      bottomNavigationBarTheme: _buildBottomNavTheme(colorScheme),

      // Dialog theme with glassmorphic style
      dialogTheme: _buildDialogTheme(colorScheme),

      // Floating action button with neon glow
      floatingActionButtonTheme: _buildFABTheme(colorScheme),
    );
  }

  /// Light theme variant (for future use)
  static ThemeData light({Color? dynamicSeedColor}) {
    final seedColor = dynamicSeedColor ?? _defaultNeon;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(colorScheme),
      inputDecorationTheme: _buildInputDecorationTheme(colorScheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      cardTheme: _buildCardTheme(colorScheme),
      appBarTheme: _buildAppBarTheme(colorScheme),
      bottomNavigationBarTheme: _buildBottomNavTheme(colorScheme),
      dialogTheme: _buildDialogTheme(colorScheme),
      floatingActionButtonTheme: _buildFABTheme(colorScheme),
    );
  }

  // Text theme with Google Fonts
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      // Headings with Orbitron (futuristic sci-fi font)
      displayLarge: GoogleFonts.orbitron(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: colorScheme.onBackground,
      ),
      displayMedium: GoogleFonts.orbitron(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: colorScheme.onBackground,
      ),
      displaySmall: GoogleFonts.orbitron(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: colorScheme.onBackground,
      ),
      headlineLarge: GoogleFonts.orbitron(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: colorScheme.onBackground,
      ),
      headlineMedium: GoogleFonts.orbitron(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: colorScheme.onBackground,
      ),
      headlineSmall: GoogleFonts.orbitron(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: colorScheme.onBackground,
      ),

      // Body text with Inter (clean, readable)
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: colorScheme.onBackground,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: colorScheme.onBackground,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: colorScheme.onBackground.withOpacity(0.8),
      ),

      // Labels with Inter
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colorScheme.onBackground,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: colorScheme.onBackground,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: colorScheme.onBackground.withOpacity(0.8),
      ),

      // Titles with Orbitron
      titleLarge: GoogleFonts.orbitron(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: colorScheme.onBackground,
      ),
      titleMedium: GoogleFonts.orbitron(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: colorScheme.onBackground,
      ),
      titleSmall: GoogleFonts.orbitron(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colorScheme.onBackground,
      ),
    );
  }

  // Input decoration with glass style and floating neon label
  static InputDecorationTheme _buildInputDecorationTheme(
      ColorScheme colorScheme) {
    final neonColor = colorScheme.primary;

    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: neonColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: neonColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: neonColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.error.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 2,
        ),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: neonColor.withOpacity(0.8),
      ),
      floatingLabelStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: neonColor,
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: colorScheme.onBackground.withOpacity(0.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  // Elevated button with glass fill and neon border
  static ElevatedButtonThemeData _buildElevatedButtonTheme(
      ColorScheme colorScheme) {
    final neonColor = colorScheme.primary;

    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.08),
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: neonColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        textStyle: GoogleFonts.orbitron(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) {
            return neonColor.withOpacity(0.15);
          }
          if (states.contains(WidgetState.pressed)) {
            return neonColor.withOpacity(0.25);
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
          if (states.contains(WidgetState.hovered)) {
            return BorderSide(
              color: neonColor.withOpacity(0.8),
              width: 2,
            );
          }
          return BorderSide(
            color: neonColor.withOpacity(0.4),
            width: 1.5,
          );
        }),
      ),
    );
  }

  // Card theme with glass effect
  static CardThemeData _buildCardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      elevation: 0,
      color: Colors.white.withOpacity(0.08),
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.primary.withOpacity(0.4),
          width: 1.5,
        ),
      ),
    );
  }

  // App bar with glass background
  static AppBarTheme _buildAppBarTheme(ColorScheme colorScheme) {
    return AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onBackground,
      centerTitle: true,
      titleTextStyle: GoogleFonts.orbitron(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        color: colorScheme.onBackground,
      ),
    );
  }

  // Bottom navigation with glass effect
  static BottomNavigationBarThemeData _buildBottomNavTheme(
      ColorScheme colorScheme) {
    return BottomNavigationBarThemeData(
      backgroundColor: Colors.white.withOpacity(0.05),
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onBackground.withOpacity(0.6),
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    );
  }

  // Dialog theme with glassmorphic style
  static DialogThemeData _buildDialogTheme(ColorScheme colorScheme) {
    return DialogThemeData(
      elevation: 0,
      backgroundColor: _darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.primary.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      titleTextStyle: GoogleFonts.orbitron(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colorScheme.onBackground,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colorScheme.onBackground,
      ),
    );
  }

  // Floating action button with neon glow
  static FloatingActionButtonThemeData _buildFABTheme(ColorScheme colorScheme) {
    return FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: Colors.black,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

/// Extension to add neon glow effect to any Color
extension NeonGlow on Color {
  /// Creates a neon glow box shadow effect
  ///
  /// [spread] - How far the glow spreads (default: 0)
  /// [blur] - Blur radius of the glow (default: 20)
  /// [opacity] - Opacity of the glow (default: 0.5)
  List<BoxShadow> neonGlow({
    double spread = 0,
    double blur = 20,
    double opacity = 0.5,
  }) {
    return [
      BoxShadow(
        color: withOpacity(opacity),
        blurRadius: blur,
        spreadRadius: spread,
        offset: Offset.zero,
      ),
      BoxShadow(
        color: withOpacity(opacity * 0.5),
        blurRadius: blur * 1.5,
        spreadRadius: spread * 1.5,
        offset: Offset.zero,
      ),
    ];
  }
}

/// Extension to create glassmorphic containers
extension GlassyWidgets on ThemeData {
  /// Creates a glassmorphic card decoration with backdrop blur
  ///
  /// [neonColor] - Border and glow color (uses primary if not provided)
  BoxDecoration glassyCard({Color? neonColor}) {
    final borderColor = neonColor ?? colorScheme.primary;

    return BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: borderColor.withOpacity(0.4),
        width: 1.5,
      ),
      boxShadow: [
        // Inner shadow effect (simulated with inset-like positioning)
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        // Subtle outer glow
        BoxShadow(
          color: borderColor.withOpacity(0.1),
          blurRadius: 15,
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Creates a glassmorphic surface decoration (lighter than card)
  ///
  /// [neonColor] - Border and glow color (uses primary if not provided)
  BoxDecoration glassySurface({Color? neonColor}) {
    final borderColor = neonColor ?? colorScheme.primary;

    return BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: borderColor.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Creates a neon border decoration
  ///
  /// [neonColor] - Border color (uses primary if not provided)
  /// [width] - Border width (default: 1.5)
  /// [radius] - Border radius (default: 16)
  BoxDecoration neonBorder({
    Color? neonColor,
    double width = 1.5,
    double radius = 16,
  }) {
    final borderColor = neonColor ?? colorScheme.primary;

    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor,
        width: width,
      ),
      boxShadow: borderColor.neonGlow(blur: 15, opacity: 0.4),
    );
  }
}

/// Widget wrapper for glassmorphic containers with backdrop filter
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final Color? neonColor;
  final double blur;
  final double borderRadius;
  final EdgeInsets? padding;
  final double? width;
  final double? height;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.neonColor,
    this.blur = 25,
    this.borderRadius = 20,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = neonColor ?? theme.colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              // Inner shadow simulation
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              // Subtle neon glow
              BoxShadow(
                color: borderColor.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Animated button with pulsing neon glow effect
class NeonPulseButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? neonColor;

  const NeonPulseButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.neonColor,
  });

  @override
  State<NeonPulseButton> createState() => _NeonPulseButtonState();
}

class _NeonPulseButtonState extends State<NeonPulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startPulse() {
    _controller.repeat(reverse: true);
  }

  void _stopPulse() {
    _controller.stop();
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neonColor = widget.neonColor ?? theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _startPulse();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _stopPulse();
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isHovered
                  ? neonColor.neonGlow(
                      blur: 25,
                      opacity: _pulseAnimation.value,
                    )
                  : null,
            ),
            child: ElevatedButton(
              onPressed: widget.onPressed,
              style: ElevatedButton.styleFrom(
                side: BorderSide(
                  color: _isHovered
                      ? neonColor.withOpacity(_pulseAnimation.value)
                      : neonColor.withOpacity(0.4),
                  width: _isHovered ? 2 : 1.5,
                ),
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}
