import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/user_notifier.dart';
import '../../widgets/unified_game_selection_sheet.dart';
import '../../domain/entities/game.dart';

/// Pin Game Dialog - now delegates to UnifiedGameSelectionSheet
/// for consistent UI/UX across the app
class PinGameDialog {
  /// Show the unified game selection sheet for pinning games
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();

    await UnifiedGameSelectionSheet.show(
      context,
      title: 'Pin Your Favorite Games',
      subtitle: 'Add games for quick access in lobbies',
      showPinnedGames: false, // Don't show already pinned games when adding
      showSearchButton: true,
      showMaxSpotSelector: false,
      onGameSelected: (Game game) async {
        try {
          await ref
              .read(userNotifierProvider.notifier)
              .addPinnedGame(game.toJson());

          if (context.mounted) {
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${game.name} pinned successfully!'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to pin game: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
    );
  }
}
