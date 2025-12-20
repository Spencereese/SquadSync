import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../domain/entities/game.dart';
import '../presentation/notifiers/game_notifier.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../presentation/notifiers/lobby_notifier.dart' as ln;
import '../screens/lobby_tab_screen.dart';
import 'game_tile.dart';
import 'game_search_delegate.dart';

/// Unified game selection widget - single source of truth for game selection UI
///
/// Configurable for different contexts:
/// - Chat: Simple game picker for creating lobbies
/// - Lobby: Game switcher with pinned games
/// - Onboarding: Multi-select with max 6 games + primary selection
/// - Display: Read-only game showcase
///
/// Features:
/// - Multiple selection modes (single/multi)
/// - Primary game designation (onboarding)
/// - Max selection limit
/// - Popular games from assets/popular_games.json
/// - IGDB search integration
/// - Pinned games support
/// - Material 3 theming
/// - Haptic feedback
///
/// Usage:
/// ```dart
/// // Onboarding multi-select
/// GameSelectionWidget(
///   isOnboarding: true,
///   allowMultipleSelect: true,
///   maxSelections: 6,
///   onGamesSelected: (games) => ...,
/// )
///
/// // Chat lobby creation
/// GameSelectionWidget(
///   onGameSelected: (game) => ...,
///   showMaxSpotSelector: true,
/// )
/// ```
class GameSelectionWidget extends ConsumerStatefulWidget {
  // Context configuration
  final bool isOnboarding;
  final bool allowMultipleSelect;
  final bool isDisplayOnly;
  final bool showSearchButton;
  final bool showMaxSpotSelector;
  final bool showPinnedGames;
  final bool isPrivateLobby;
  final String? chatGroupId;

  // Selection configuration
  final int? maxSelections;
  final List<Game>? initialSelectedGames;
  final String? primaryGameSlug;

  // Callbacks
  final Function(Game)? onGameSelected;
  final Function(List<Game>)? onGamesSelected;
  final Function(String gameName, int maxSpots)? onGameWithSpotsSelected;
  final Function(String gameName, int maxSpots)? onLobbyCreated;
  final Function(String slug)? onPrimaryGameChanged;

  // Display configuration
  final GameTileStyle tileStyle;
  final String? title;
  final String? subtitle;
  final Widget? header;
  final Widget? footer;

  const GameSelectionWidget({
    super.key,
    this.isOnboarding = false,
    this.allowMultipleSelect = false,
    this.isDisplayOnly = false,
    this.showSearchButton = true,
    this.showMaxSpotSelector = false,
    this.showPinnedGames = true,
    this.isPrivateLobby = false,
    this.chatGroupId,
    this.maxSelections,
    this.initialSelectedGames,
    this.primaryGameSlug,
    this.onGameSelected,
    this.onGamesSelected,
    this.onGameWithSpotsSelected,
    this.onLobbyCreated,
    this.onPrimaryGameChanged,
    this.tileStyle = GameTileStyle.grid,
    this.title,
    this.subtitle,
    this.header,
    this.footer,
  });

  @override
  ConsumerState<GameSelectionWidget> createState() =>
      _GameSelectionWidgetState();
}

class _GameSelectionWidgetState extends ConsumerState<GameSelectionWidget> {
  late List<Game> _selectedGames;
  late String? _primaryGameSlug;
  List<Game> _popularGames = [];
  int _maxSpots = 8;
  bool _isLoadingPopular = false;

  @override
  void initState() {
    super.initState();
    _selectedGames = widget.initialSelectedGames?.toList() ?? [];
    _primaryGameSlug = widget.primaryGameSlug;
    _loadPopularGames();
  }

  Future<void> _loadPopularGames() async {
    setState(() => _isLoadingPopular = true);

    try {
      // Load from assets/popular_games.json
      final jsonString =
          await rootBundle.loadString('assets/popular_games.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      final popularFromAssets = jsonData
          .where((json) => _hasMultiplayer(json as Map<String, dynamic>))
          .take(20)
          .map((json) => Game.fromIgdb(json as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _popularGames = popularFromAssets;
          _isLoadingPopular = false;
        });
      }

      // Optionally load trending from IGDB (in background)
      _loadTrendingGames();
    } catch (e) {
      debugPrint('Error loading popular games: $e');
      if (mounted) {
        setState(() => _isLoadingPopular = false);
      }
    }
  }

  Future<void> _loadTrendingGames() async {
    try {
      final result =
          await ref.read(gameNotifierProvider.notifier).loadPopularGames();
      result.whenData((games) {
        if (mounted && games.isNotEmpty) {
          setState(() {
            // Merge with existing popular games, dedupe by slug
            final allGames = [..._popularGames, ...games];
            final Map<String, Game> deduped = {};
            for (final game in allGames) {
              deduped[game.slug] = game;
            }
            _popularGames = deduped.values.take(20).toList();
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading trending games: $e');
    }
  }

  /// Check if a game has multiplayer capabilities
  bool _hasMultiplayer(Map<String, dynamic> game) {
    // Check for multiplayer_modes field
    final hasMpModes = game['multiplayer_modes'] != null &&
        (game['multiplayer_modes'] as List).isNotEmpty;

    // Check game_modes for multiplayer indicators
    final gameModes = game['game_modes'] as List<dynamic>?;
    final hasMultiplayerMode = gameModes?.any((mode) {
          final modeName = (mode['name'] as String? ?? '').toLowerCase();
          return modeName.contains('multiplayer') ||
              modeName.contains('co-op') ||
              modeName.contains('mmo') ||
              modeName.contains('battle royale') ||
              modeName.contains('split');
        }) ??
        false;

    return hasMpModes || hasMultiplayerMode;
  }

  void _toggleGameSelection(Game game) {
    if (widget.isDisplayOnly) return;

    HapticFeedback.selectionClick();

    setState(() {
      final index = _selectedGames.indexWhere((g) => g.slug == game.slug);

      if (index != -1) {
        // Remove game
        _selectedGames.removeAt(index);

        // If this was the primary game, set a new primary
        if (_primaryGameSlug == game.slug) {
          _primaryGameSlug =
              _selectedGames.isNotEmpty ? _selectedGames.first.slug : null;
          widget.onPrimaryGameChanged?.call(_primaryGameSlug ?? '');
        }
      } else {
        // Add game
        if (widget.allowMultipleSelect) {
          if (widget.maxSelections != null &&
              _selectedGames.length >= widget.maxSelections!) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Maximum ${widget.maxSelections} games allowed'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }
          _selectedGames.add(game);

          // First selected game becomes primary in onboarding
          if (widget.isOnboarding && _selectedGames.length == 1) {
            _primaryGameSlug = game.slug;
            widget.onPrimaryGameChanged?.call(_primaryGameSlug!);
          }

          widget.onGamesSelected?.call(_selectedGames);
        } else {
          // Single select
          _selectedGames = [game];

          if (widget.isPrivateLobby) {
            // Create private lobby for chat
            _createPrivateLobby(game);
          } else if (widget.showMaxSpotSelector) {
            widget.onGameWithSpotsSelected?.call(game.name, _maxSpots);
          } else {
            widget.onGameSelected?.call(game);
          }
        }
      }
    });
  }

  void _setPrimaryGame(String slug) {
    if (widget.isDisplayOnly || !widget.isOnboarding) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _primaryGameSlug = slug;
    });
    widget.onPrimaryGameChanged?.call(slug);
  }

  Future<void> _createPrivateLobby(Game game) async {
    if (widget.chatGroupId == null) return;

    try {
      final lobbyId =
          await ref.read(ln.lobbyNotifierProvider.notifier).createLobby(
                chatGroupId: widget.chatGroupId!,
                gameName: game.name,
                maxSpots: _maxSpots,
                isPublic: false,
              );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Private lobby created for ${game.name}!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        widget.onLobbyCreated?.call(game.name, _maxSpots);
        Navigator.of(context).pop(); // Close the sheet

        // Navigate to lobby tab screen with the new lobby ID
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LobbyTabScreen(
              lobbyId: lobbyId,
              gameName: game.name,
              game: game.toJson(),
              chatGroupId: widget.chatGroupId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create lobby: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showSearch() async {
    final selectedGame = await GameSearchDelegate.show(
      context,
      ref: ref,
      multiSelect: widget.allowMultipleSelect,
      selectedGames: _selectedGames,
      maxSelections: widget.maxSelections,
    );

    if (selectedGame != null) {
      _toggleGameSelection(selectedGame);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(userNotifierProvider);
    final pinnedGames = userAsync.maybeWhen(
      data: (userState) => (userState?.pinnedGames ?? <String>[])
          .map((e) => e.toString())
          .toList(),
      orElse: () => <String>[],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (widget.header != null)
              widget.header!
            else
              _buildDefaultHeader(theme),

            const SizedBox(height: 16),

            // Max spots selector (for chat lobby creation)
            if (widget.showMaxSpotSelector) _buildMaxSpotSelector(theme),

            // Search button
            if (widget.showSearchButton) ...[
              _buildSearchButton(theme),
              const SizedBox(height: 16),
            ],

            // Active lobbies section (if chat group context)
            if (widget.chatGroupId != null) ...[
              _buildActiveLobbiesSection(theme, ref),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // Pinned games section
            if (widget.showPinnedGames && pinnedGames.isNotEmpty) ...[
              _buildPinnedGamesSection(theme, pinnedGames),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // Popular games section
            _buildPopularGamesSection(theme),

            // Footer
            if (widget.footer != null) ...[
              const SizedBox(height: 16),
              widget.footer!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title ?? 'Select Game',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMaxSpotSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            'Max Spots:',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Slider(
              value: _maxSpots.toDouble(),
              min: 2,
              max: 12,
              divisions: 10,
              label: _maxSpots.toString(),
              onChanged: (value) {
                setState(() => _maxSpots = value.toInt());
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Text(
              _maxSpots.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                shadows:
                    theme.colorScheme.primary.neonGlow(blur: 8, opacity: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showSearch,
        icon: Icon(Icons.search, color: theme.colorScheme.primary),
        label: Text(
          'Search IGDB',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          side: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.5),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveLobbiesSection(ThemeData theme, WidgetRef ref) {
    final lobbyStateAsync = ref.watch(ln.lobbyNotifierProvider);

    return lobbyStateAsync.when(
      data: (lobbyState) {
        // Get active lobbies for this chat group
        final activeLobbies = <Map<String, dynamic>>[];

        // Check for private lobbies in this chat group
        lobbyState.gameLobbies.forEach((gameName, lobbies) {
          for (final lobby in lobbies) {
            if (lobby['chatGroupId'] == widget.chatGroupId &&
                lobby['isActive'] == true) {
              activeLobbies.add({...lobby, 'gameName': gameName});
            }
          }
        });

        // Check if any group members are in public lobbies
        lobbyState.gameLobbies.forEach((gameName, lobbies) {
          for (final lobby in lobbies) {
            if (lobby['isActive'] == true &&
                lobby['chatGroupId'] != widget.chatGroupId) {
              // Check if any member UIDs are in this lobby's spots
              final spots = lobby['spots'] as List<String?>? ?? [];
              final hasGroupMember = spots.any((uid) =>
                  uid != null && lobbyState.lobbyMemberUids.contains(uid));
              if (hasGroupMember) {
                activeLobbies
                    .add({...lobby, 'gameName': gameName, 'isPublic': true});
              }
            }
          }
        });

        if (activeLobbies.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gamepad, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Active Lobbies',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...activeLobbies.map((lobby) {
              final gameName = lobby['gameName'] as String;
              final isPublic = lobby['isPublic'] == true;
              final spots = lobby['spots'] as List<String?>? ?? [];
              final filledSpots = spots.where((s) => s != null).length;
              final maxSpots = lobby['maxSpots'] as int? ?? 8;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPublic ? Icons.public : Icons.lock,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gameName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isPublic ? 'Public Lobby' : 'Private Lobby',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$filledSpots/$maxSpots',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPinnedGamesSection(ThemeData theme, List<String> pinnedGames) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.push_pin, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Pinned Games',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: pinnedGames.map((gameName) {
            // Convert string to Game object
            final game = Game(
              name: gameName,
              slug: gameName.toLowerCase().replaceAll(' ', '-'),
              igdbId: null,
              coverUrl: null,
              summary: null,
              firstReleaseDate: null,
              genres: [],
              platforms: [],
              maxSpots: null,
              isCached: false,
              cachedAt: null,
            );
            final isSelected = _selectedGames.any((g) => g.slug == game.slug);
            final isPrimary = _primaryGameSlug == game.slug;

            return GameTile(
              game: game,
              isSelected: isSelected,
              isPrimary: isPrimary,
              style: widget.tileStyle,
              onTap: () => _toggleGameSelection(game),
              onLongPress:
                  widget.isOnboarding ? () => _setPrimaryGame(game.slug) : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPopularGamesSection(ThemeData theme) {
    if (_isLoadingPopular) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (_popularGames.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No multiplayer games available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up,
                size: 18, color: theme.colorScheme.secondary),
            const SizedBox(width: 8),
            Text(
              'Popular Multiplayer Games',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Make scrollable with max height constraint
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _popularGames.map((game) {
                final isSelected =
                    _selectedGames.any((g) => g.slug == game.slug);
                final isPrimary = _primaryGameSlug == game.slug;

                return GameTile(
                  game: game,
                  isSelected: isSelected,
                  isPrimary: isPrimary,
                  style: widget.tileStyle,
                  onTap: () => _toggleGameSelection(game),
                  onLongPress: widget.isOnboarding
                      ? () => _setPrimaryGame(game.slug)
                      : null,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
