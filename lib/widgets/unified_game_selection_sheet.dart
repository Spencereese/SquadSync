import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../domain/entities/game.dart';
import 'game_selection_widget.dart';
import 'game_tile.dart';

/// Unified game selection bottom sheet with consistent Material 3 glassmorphic theme
///
/// Single source of truth for all game selection UI across the app:
/// - Chat: Creating lobbies with game selection
/// - Lobby: Switching games in existing lobbies
/// - Profile: Adding/managing pinned games
///
/// Features:
/// - Glassmorphic container with backdrop blur
/// - Neon glow accents from app theme
/// - Consistent drag handle
/// - Material 3 color scheme integration
/// - Haptic feedback
class UnifiedGameSelectionSheet extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final bool showMaxSpotSelector;
  final bool showPinnedGames;
  final bool showSearchButton;
  final bool allowMultipleSelect;
  final int? maxSelections;
  final Function(Game)? onGameSelected;
  final Function(String gameName, int maxSpots)? onGameWithSpotsSelected;
  final Function(String gameName, int maxSpots)? onLobbyCreated;
  final bool isPrivateLobby;
  final String? chatGroupId;

  const UnifiedGameSelectionSheet({
    super.key,
    this.title = 'Select Game',
    this.subtitle,
    this.showMaxSpotSelector = false,
    this.showPinnedGames = true,
    this.showSearchButton = true,
    this.allowMultipleSelect = false,
    this.maxSelections,
    this.onGameSelected,
    this.onGameWithSpotsSelected,
    this.onLobbyCreated,
    this.isPrivateLobby = false,
    this.chatGroupId,
  });

  /// Show the unified game selection sheet
  static Future<void> show(
    BuildContext context, {
    String title = 'Select Game',
    String? subtitle,
    bool showMaxSpotSelector = false,
    bool showPinnedGames = true,
    bool showSearchButton = true,
    bool allowMultipleSelect = false,
    int? maxSelections,
    Function(Game)? onGameSelected,
    Function(String gameName, int maxSpots)? onGameWithSpotsSelected,
    Function(String gameName, int maxSpots)? onLobbyCreated,
    bool isPrivateLobby = false,
    String? chatGroupId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UnifiedGameSelectionSheet(
        title: title,
        subtitle: subtitle,
        showMaxSpotSelector: showMaxSpotSelector,
        showPinnedGames: showPinnedGames,
        showSearchButton: showSearchButton,
        allowMultipleSelect: allowMultipleSelect,
        maxSelections: maxSelections,
        onGameSelected: onGameSelected,
        onGameWithSpotsSelected: onGameWithSpotsSelected,
        onLobbyCreated: onLobbyCreated,
        isPrivateLobby: isPrivateLobby,
        chatGroupId: chatGroupId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final neonColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {}, // Prevent dismissal when tapping content
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return GlassmorphicContainer(
                neonColor: neonColor,
                blur: 30,
                borderRadius: 24,
                child: Column(
                  children: [
                    // Drag handle with neon glow
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: neonColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: neonColor.neonGlow(
                          blur: 10,
                          opacity: 0.3,
                        ),
                      ),
                    ),

                    // Header with Orbitron font
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: neonColor,
                                    shadows: neonColor.neonGlow(
                                      blur: 10,
                                      opacity: 0.3,
                                    ),
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Close button with glassmorphic background
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                            icon: Icon(
                              Icons.close,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.surface.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: neonColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // Game selection widget
                    Expanded(
                      child: GameSelectionWidget(
                        showMaxSpotSelector: showMaxSpotSelector,
                        showPinnedGames: showPinnedGames,
                        showSearchButton: showSearchButton,
                        allowMultipleSelect: allowMultipleSelect,
                        maxSelections: maxSelections,
                        tileStyle: GameTileStyle.list,
                        isPrivateLobby: isPrivateLobby,
                        chatGroupId: chatGroupId,
                        onGameSelected: onGameSelected != null
                            ? (game) {
                                HapticFeedback.mediumImpact();
                                onGameSelected!(game);
                                Navigator.of(context).pop();
                              }
                            : null,
                        onGameWithSpotsSelected: onGameWithSpotsSelected != null
                            ? (gameName, maxSpots) {
                                HapticFeedback.mediumImpact();
                                onGameWithSpotsSelected!(gameName, maxSpots);
                                Navigator.of(context).pop();
                              }
                            : null,
                        onLobbyCreated: onLobbyCreated,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
