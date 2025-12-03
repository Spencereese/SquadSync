import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/game_notifier.dart';
import '../controllers/game_theme_controller.dart';

/// Hook that watches for game selection changes and updates theme accordingly
///
/// Call this in any widget where you want theme to update on game change
class GameThemeSync {
  static void watch(WidgetRef ref) {
    // Watch current game from GameNotifier
    final gameState = ref.watch(gameNotifierProvider);

    gameState.maybeWhen(
      data: (state) {
        if (state.currentGame != null) {
          final game = state.currentGame!;
          final gameId = game.igdbId?.toString() ?? game.slug;
          final gameName = game.name;
          final coverUrl = game.coverUrl;

          // Update theme controller when game changes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(gameThemeControllerProvider.notifier).updateGameTheme(
                  gameId: gameId,
                  gameName: gameName,
                  coverImageUrl: coverUrl,
                );
          });
        }
      },
      orElse: () {},
    );
  }
}
