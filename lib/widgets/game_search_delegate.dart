import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/game.dart';
import '../presentation/notifiers/game_notifier.dart';
import '../presentation/notifiers/user_notifier.dart';
import 'game_tile.dart';

/// Unified game search delegate with IGDB API integration
///
/// Features:
/// - Real-time search with debouncing (300ms)
/// - Pinned games section for quick access
/// - Popular games fallback when no search query
/// - Search history (optional)
/// - Material 3 theming
/// - Haptic feedback
/// - Error handling
///
/// Usage:
/// ```dart
/// final game = await GameSearchDelegate.show(
///   context,
///   ref: ref,
///   multiSelect: false,
/// );
/// ```
class GameSearchDelegate extends SearchDelegate<Game?> {
  final WidgetRef ref;
  final bool multiSelect;
  final List<Game> selectedGames;
  final int? maxSelections;

  Timer? _debounce;
  List<Game> _searchResults = [];
  List<Game> _pinnedGames = [];
  List<Game> _popularGames = [];
  bool _isLoading = false;

  GameSearchDelegate({
    required this.ref,
    this.multiSelect = false,
    this.selectedGames = const [],
    this.maxSelections,
  }) : super(
          searchFieldLabel: 'Search games...',
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
        );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            _searchResults = [];
            showSuggestions(context);
          },
          tooltip: 'Clear search',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
      tooltip: 'Back',
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildEmptyState(context);
    }

    // Trigger search with debounce
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });

    return _buildSearchResults(context);
  }

  Future<void> _performSearch(String searchQuery) async {
    if (searchQuery.isEmpty) {
      _searchResults = [];
      _isLoading = false;
      return;
    }

    _isLoading = true;

    try {
      final result = await ref
          .read(gameNotifierProvider.notifier)
          .searchGames(searchQuery);

      result.when(
        data: (games) {
          _searchResults = games;
          _isLoading = false;
        },
        loading: () {
          _isLoading = true;
        },
        error: (error, stack) {
          _searchResults = [];
          _isLoading = false;
          debugPrint('Search error: $error');
        },
      );
    } catch (e) {
      _searchResults = [];
      _isLoading = false;
      debugPrint('Search exception: $e');
    }
  }

  Future<void> _loadPinnedGames() async {
    final userAsync = ref.watch(userNotifierProvider);
    userAsync.whenData((userState) {
      if (userState?.pinnedGames != null) {
        // Convert pinned game strings to Game objects
        _pinnedGames = userState!.pinnedGames.map((gameNameObj) {
          final gameName = gameNameObj.toString();
          // Try to find game in current state
          final gameState = ref.read(gameNotifierProvider).value;
          final existingGame = gameState?.availableGames.firstWhere(
            (g) => g.name == gameName,
            orElse: () => Game(
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
            ),
          );
          return existingGame ??
              Game(
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
        }).toList();
      }
    });
  }

  Future<void> _loadPopularGames() async {
    try {
      final result =
          await ref.read(gameNotifierProvider.notifier).loadPopularGames();
      result.whenData((games) {
        _popularGames = games.take(20).toList();
      });
    } catch (e) {
      debugPrint('Error loading popular games: $e');
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    // Load pinned and popular games
    _loadPinnedGames();
    if (_popularGames.isEmpty) {
      _loadPopularGames();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pinned games section
        if (_pinnedGames.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.push_pin,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Pinned Games',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _pinnedGames.map((game) {
              final isSelected = selectedGames.any((g) => g.slug == game.slug);
              return GameTile(
                game: game,
                isSelected: isSelected,
                style: GameTileStyle.grid,
                onTap: () => _onGameSelected(context, game),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
        ],

        // Popular games section
        Row(
          children: [
            Icon(
              Icons.trending_up,
              size: 20,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Popular Games',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_popularGames.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading popular games...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _popularGames.map((game) {
              final isSelected = selectedGames.any((g) => g.slug == game.slug);
              return GameTile(
                game: game,
                isSelected: isSelected,
                style: GameTileStyle.grid,
                onTap: () => _onGameSelected(context, game),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Searching games...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (query.isEmpty) {
      return _buildEmptyState(context);
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No games found',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final game = _searchResults[index];
        final isSelected = selectedGames.any((g) => g.slug == game.slug);

        return GameTile(
          game: game,
          isSelected: isSelected,
          style: GameTileStyle.list,
          onTap: () => _onGameSelected(context, game),
        );
      },
    );
  }

  void _onGameSelected(BuildContext context, Game game) {
    if (multiSelect) {
      // Multi-select mode: toggle selection
      final isSelected = selectedGames.any((g) => g.slug == game.slug);

      if (isSelected) {
        selectedGames.removeWhere((g) => g.slug == game.slug);
      } else {
        if (maxSelections != null && selectedGames.length >= maxSelections!) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum $maxSelections games allowed'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          return;
        }
        selectedGames.add(game);
      }

      // Refresh UI
      showSuggestions(context);
    } else {
      // Single select mode: close and return game
      close(context, game);
    }
  }

  /// Static helper to show the search delegate
  static Future<Game?> show(
    BuildContext context, {
    required WidgetRef ref,
    bool multiSelect = false,
    List<Game> selectedGames = const [],
    int? maxSelections,
  }) async {
    return await showSearch<Game?>(
      context: context,
      delegate: GameSearchDelegate(
        ref: ref,
        multiSelect: multiSelect,
        selectedGames: selectedGames,
        maxSelections: maxSelections,
      ),
    );
  }
}
