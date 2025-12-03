import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../controllers/game_theme_controller.dart';

/// Wrapper widget that applies animated theme transitions when game colors change
///
/// Wraps the app and watches for game theme changes, applying smooth
/// 600ms theme transitions using AnimatedTheme
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

    // Build dynamic theme using vibrant color as seed
    final theme = AppTheme.dark(dynamicSeedColor: gameTheme.vibrantColor);

    return AnimatedTheme(
      data: theme,
      duration: transitionDuration,
      curve: Curves.easeInOutCubic,
      child: child,
    );
  }
}
