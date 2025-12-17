import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../domain/entities/game.dart';

/// Unified game tile component for displaying games across the app
///
/// Supports multiple display modes:
/// - Grid tile: Compact grid view with cover art
/// - List tile: Expanded list view with details
/// - Card: Featured card style with hover effects
/// - Chip: Compact horizontal chip for selected games
///
/// Features:
/// - Selection state with visual feedback
/// - Primary game indicator (star badge)
/// - Cover art with fallback icon
/// - Haptic feedback on interaction
/// - Material 3 theming
class GameTile extends StatelessWidget {
  final Game? game;
  final String? gameName;
  final String? coverUrl;
  final bool isSelected;
  final bool isPrimary;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GameTileStyle style;
  final double? width;
  final double? height;
  final bool showBadge;

  const GameTile({
    super.key,
    this.game,
    this.gameName,
    this.coverUrl,
    this.isSelected = false,
    this.isPrimary = false,
    this.onTap,
    this.onLongPress,
    this.style = GameTileStyle.grid,
    this.width,
    this.height,
    this.showBadge = true,
  }) : assert(game != null || gameName != null,
            'Either game or gameName must be provided');

  String get _displayName => game?.name ?? gameName ?? 'Unknown Game';
  String? get _displayCoverUrl => game?.coverUrl ?? coverUrl;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case GameTileStyle.grid:
        return _buildGridTile(context);
      case GameTileStyle.list:
        return _buildListTile(context);
      case GameTileStyle.card:
        return _buildCardTile(context);
      case GameTileStyle.chip:
        return _buildChipTile(context);
    }
  }

  Widget _buildGridTile(BuildContext context) {
    final theme = Theme.of(context);
    final tileWidth = width ?? 120;
    final tileHeight = height ?? 200;

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.selectionClick();
          onTap!();
        }
      },
      onLongPress: () {
        if (onLongPress != null) {
          HapticFeedback.mediumImpact();
          onLongPress!();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: tileWidth,
        height: tileHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cover art or fallback icon
                if (_displayCoverUrl != null)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: _displayCoverUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.gamepad_rounded,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Icon(
                      Icons.gamepad_rounded,
                      size: 50,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                // Game name
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Primary badge
            if (isPrimary && showBadge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.star,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            // Selection checkmark
            if (isSelected && showBadge)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.selectionClick();
            onTap!();
          }
        },
        onLongPress: () {
          if (onLongPress != null) {
            HapticFeedback.mediumImpact();
            onLongPress!();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover art
              if (_displayCoverUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: _displayCoverUrl!,
                    width: 50,
                    height: 70,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 50,
                      height: 70,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 50,
                      height: 70,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.gamepad_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 50,
                  height: 70,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.gamepad_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 16),
              // Game name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPrimary)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.star,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    if (game?.summary != null && game!.summary!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          game!.summary!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Trailing icon
              Icon(
                isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardTile(BuildContext context) {
    final theme = Theme.of(context);
    final cardWidth = width ?? 180;
    final cardHeight = height ?? 240;

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap!();
        }
      },
      onLongPress: () {
        if (onLongPress != null) {
          HapticFeedback.mediumImpact();
          onLongPress!();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Cover art
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: _displayCoverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _displayCoverUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.gamepad_rounded,
                                size: 60,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.gamepad_rounded,
                              size: 60,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                // Game name
                Expanded(
                  flex: 1,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHigh,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Primary badge
            if (isPrimary && showBadge)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.star,
                    size: 20,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipTile(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.selectionClick();
          onTap!();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isPrimary ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPrimary && showBadge)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.star,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            if (_displayCoverUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: _displayCoverUrl!,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Icon(
                      Icons.gamepad_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            Text(
              _displayName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isPrimary
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (onLongPress != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Display style for GameTile
enum GameTileStyle {
  /// Compact grid view (120x160)
  grid,

  /// Expanded list view with details
  list,

  /// Featured card style (180x240)
  card,

  /// Compact horizontal chip
  chip,
}
