import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../managers/game_manager.dart';
import '../../managers/user_manager.dart';

class GameSelectionCard extends StatefulWidget {
  final TextEditingController controller;
  final Function(Map<String, dynamic>?) onGameSelected;
  final Map<String, dynamic>? selectedGame;

  const GameSelectionCard({
    super.key,
    required this.controller,
    required this.onGameSelected,
    this.selectedGame,
  });

  @override
  State<GameSelectionCard> createState() => _GameSelectionCardState();
}

class _GameSelectionCardState extends State<GameSelectionCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              Icons.videogame_asset_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Choose Game',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search field
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: TypeAheadField(
            controller: widget.controller,
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search for a game...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              );
            },
            suggestionsCallback: (pattern) async {
              final userManager =
                  Provider.of<UserManager>(context, listen: false);
              final pinnedGames = userManager.pinnedGames;

              if (pattern.isEmpty) {
                return pinnedGames
                    .map((game) => {
                          'name': game['name'],
                          'slug': game['slug'] ??
                              game['name']
                                  ?.toString()
                                  .toLowerCase()
                                  .replaceAll(' ', '-'),
                          'coverUrl': game['coverUrl'],
                          'summary': game['summary'],
                          'genres': game['genres'],
                          'maxSpots': game['maxSpots'] ?? 4,
                        })
                    .toList();
              }

              final gameManager =
                  Provider.of<GameManager>(context, listen: false);
              return await (gameManager as dynamic).searchGames(pattern);
            },
            itemBuilder: (context, suggestion) {
              final game = suggestion as Map<String, dynamic>;
              final coverUrl = game['coverUrl'] as String?;
              return Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: coverUrl != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(coverUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: coverUrl == null
                          ? Icon(
                              Icons.videogame_asset_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game['name'] as String? ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (game['genres'] != null)
                            Text(
                              (game['genres'] as List<dynamic>?)?.join(', ') ??
                                  '',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            onSelected: (suggestion) async {
              final game = suggestion as Map<String, dynamic>;
              widget.controller.text = game['name'] as String? ?? '';
              widget.onGameSelected(game);
              // Ensure suggestions close
              FocusScope.of(context).unfocus();
            },
            emptyBuilder: (context) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No games found',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ),

        // Selected game preview
        if (widget.selectedGame != null) ...[
          const SizedBox(height: 16),
          GamePreviewCard(
            game: widget.selectedGame!,
            onRemove: () => widget.onGameSelected(null),
          ),
        ],
      ],
    );
  }
}

class GamePreviewCard extends StatelessWidget {
  final Map<String, dynamic> game;
  final VoidCallback onRemove;

  const GamePreviewCard({
    super.key,
    required this.game,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = game['coverUrl'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: coverUrl != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(coverUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: coverUrl == null
                ? Icon(
                    Icons.videogame_asset_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game['name'] ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Max players: ${game['maxSpots'] ?? 4}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
