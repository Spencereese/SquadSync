import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../controllers/game_theme_controller.dart';
import '../../domain/entities/system_state.dart' as system_state;
import '../notifiers/system_notifier.dart';

/// Wrapper widget that applies animated theme transitions when game colors change
///
/// Wraps the app and watches for game theme changes, applying smooth
/// 600ms theme transitions using AnimatedTheme with easeInOutCubic curve.
/// Supports dynamic ColorScheme from IGDB covers, system brightness detection,
/// and accessibility features (high contrast mode).
class AnimatedThemeWrapper extends ConsumerWidget {
  final Widget child;
  final Duration transitionDuration;

  const AnimatedThemeWrapper({
    super.key,
    required this.child,
    this.transitionDuration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch game theme state for color changes
    final gameTheme = ref.watch(gameThemeControllerProvider);

    // Watch system state for theme mode
    final systemState = ref.watch(systemNotifierProvider);

    // Determine effective brightness
    final brightness = systemState.whenOrNull(
          data: (state) {
            switch (state.themeMode) {
              case system_state.ThemeMode.light:
                return Brightness.light;
              case system_state.ThemeMode.dark:
                return Brightness.dark;
              case system_state.ThemeMode.system:
                return gameTheme.systemBrightness;
            }
          },
        ) ??
        gameTheme.systemBrightness;

    // Build dynamic theme with extracted colors and dynamic ColorScheme
    final theme = brightness == Brightness.dark
        ? AppTheme.dark(
            dynamicSeedColor: gameTheme.vibrantColor,
            dynamicColorScheme: gameTheme.dynamicColorScheme,
            neonGlowEnabled: gameTheme.neonGlowEnabled,
            highContrastMode: gameTheme.highContrastMode,
          )
        : AppTheme.light(
            dynamicSeedColor: gameTheme.vibrantColor,
            dynamicColorScheme: gameTheme.dynamicColorScheme,
            neonGlowEnabled: gameTheme.neonGlowEnabled,
            highContrastMode: gameTheme.highContrastMode,
          );

    return AnimatedTheme(
      data: theme,
      duration: transitionDuration,
      curve: Curves.easeInOutCubic,
      child: child,
    );
  }
}
