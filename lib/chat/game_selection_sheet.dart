import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/game_selection_widget.dart';
import '../widgets/game_tile.dart';

/// Game selection bottom sheet for creating lobbies
///
/// Delegates to GameSelectionWidget for core functionality
/// Used in both chat groups (private lobbies) and public lobby creation
class GameSelectionSheet extends ConsumerStatefulWidget {
  final Function(String gameName, int maxSpots)? onGameSelected;
  final Function(String gameName, int maxSpots)? onLobbyCreated;
  final bool showPublicToggle;
  final bool isPrivateLobby;
  final String? chatGroupId;

  const GameSelectionSheet({
    super.key,
    this.onGameSelected,
    this.onLobbyCreated,
    this.showPublicToggle = false,
    this.isPrivateLobby = false,
    this.chatGroupId,
  });

  static Future<void> show(
    BuildContext context, {
    Function(String gameName, int maxSpots)? onGameSelected,
    Function(String gameName, int maxSpots)? onLobbyCreated,
    bool showPublicToggle = false,
    bool isPrivateLobby = false,
    String? chatGroupId,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GameSelectionSheet(
        onGameSelected: onGameSelected,
        onLobbyCreated: onLobbyCreated,
        showPublicToggle: showPublicToggle,
        isPrivateLobby: isPrivateLobby,
        chatGroupId: chatGroupId,
      ),
    );
  }

  @override
  ConsumerState<GameSelectionSheet> createState() => _GameSelectionSheetState();
}

class _GameSelectionSheetState extends ConsumerState<GameSelectionSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Game selection widget (delegates to unified component)
          Expanded(
            child: GameSelectionWidget(
              title: 'Select Game',
              subtitle: widget.isPrivateLobby
                  ? 'Choose a game to create a private lobby'
                  : 'Choose a game to create a lobby',
              showMaxSpotSelector: true,
              showSearchButton: true,
              showPinnedGames: true,
              tileStyle: GameTileStyle.list,
              isPrivateLobby: widget.isPrivateLobby,
              chatGroupId: widget.chatGroupId,
              onGameWithSpotsSelected: widget.onGameSelected != null
                  ? (gameName, maxSpots) {
                      HapticFeedback.mediumImpact();
                      widget.onGameSelected!(gameName, maxSpots);
                      Navigator.pop(context);
                    }
                  : null,
              onLobbyCreated: widget.onLobbyCreated,
            ),
          ),
        ],
      ),
    );
  }
}
