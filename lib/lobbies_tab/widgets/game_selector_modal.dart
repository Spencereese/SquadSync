import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../core/app_theme.dart';
import '../../domain/entities/game.dart';
import '../../presentation/notifiers/game_state_notifier.dart';
import '../../presentation/notifiers/game_notifier.dart';
import '../../presentation/notifiers/user_notifier.dart';

/// Game selector modal with favorite games carousel
/// Opens from the lobby tab's game selector button
class GameSelectorModal extends ConsumerStatefulWidget {
  final Function(Game) onGameSelected;
  final VoidCallback onDismiss;

  const GameSelectorModal({
    super.key,
    required this.onGameSelected,
    required this.onDismiss,
  });

  static Future<Game?> show(
    BuildContext context, {
    required Function(Game) onGameSelected,
  }) async {
    Game? selectedGame;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GameSelectorModal(
        onGameSelected: (game) {
          selectedGame = game;
          onGameSelected(game);
          Navigator.of(context).pop();
        },
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );

    return selectedGame;
  }

  @override
  ConsumerState<GameSelectorModal> createState() => _GameSelectorModalState();
}

class _GameSelectorModalState extends ConsumerState<GameSelectorModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final TextEditingController _searchController = TextEditingController();

  List<Game> _favoriteGames = [];
  List<Game> _recentGames = [];
  List<Game> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // Initialize animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    // Start animation
    _animationController.forward();

    // Load data
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() => _isLoading = true);

    try {
      // Get favorite games from user preferences
      final userState = ref.read(userNotifierProvider).value;
      if (userState?.pinnedGames != null && userState!.pinnedGames.isNotEmpty) {
        _favoriteGames = userState.pinnedGames
            .map((g) {
              try {
                return Game.fromCache(g);
              } catch (e) {
                debugPrint('Error parsing favorite game: $e');
                return null;
              }
            })
            .where((g) => g != null)
            .cast<Game>()
            .toList();
      }

      // Get game history (recent games)
      final gameState = await ref.read(gameStateNotifierProvider.future);
      _recentGames = gameState.gameHistory
          .take(5)
          .map((g) {
            try {
              return Game.fromCache(g);
            } catch (e) {
              debugPrint('Error parsing recent game: $e');
              return null;
            }
          })
          .where((g) => g != null)
          .cast<Game>()
          .toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading games: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaleTransition(
      scale: _animation,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.7],
            builder: (context, scrollController) {
              return Container(
                decoration: theme.glassyCard(),
                child: Column(
                  children: [
                    _buildDragHandle(theme),
                    _buildHeader(theme),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.all(20),
                              child: _buildContent(theme),
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

  Widget _buildDragHandle(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.gamepad,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'Select Game',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar - ABOVE the carousel
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search all games...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _searchResults = [];
                        _isSearching = false;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: theme.colorScheme.primary.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          onChanged: (query) async {
            setState(() {
              _searchQuery = query;
              _isSearching = query.isNotEmpty;
            });

            if (query.isEmpty) {
              setState(() => _searchResults = []);
              return;
            }

            // Debounce search
            await Future.delayed(const Duration(milliseconds: 300));
            if (_searchQuery != query) return;

            // Perform IGDB search
            try {
              final result = await ref
                  .read(gameNotifierProvider.notifier)
                  .searchGames(query);

              result.when(
                data: (games) {
                  if (mounted && _searchQuery == query) {
                    setState(() => _searchResults = games);
                  }
                },
                loading: () {},
                error: (e, st) {
                  debugPrint('Search error: $e');
                  if (mounted) setState(() => _searchResults = []);
                },
              );
            } catch (e) {
              debugPrint('Search exception: $e');
            }
          },
        ),
        const SizedBox(height: 20),

        // Show search results OR favorite games
        if (_isSearching && _searchResults.isNotEmpty) ...[
          _buildSectionHeader(theme, 'Search Results', Icons.search),
          const SizedBox(height: 12),
          _buildGamesCarousel(_searchResults, theme),
          const SizedBox(height: 24),
        ] else if (_isSearching) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          ),
        ] else ...[
          // Favorite Games Carousel
          if (_favoriteGames.isNotEmpty) ...[
            _buildSectionHeader(theme, 'Favorite Games', Icons.star),
            const SizedBox(height: 12),
            _buildGamesCarousel(_favoriteGames, theme),
            const SizedBox(height: 24),
          ],

          // Recent Games
          if (_recentGames.isNotEmpty) ...[
            _buildSectionHeader(theme, 'Recently Played', Icons.history),
            const SizedBox(height: 12),
            _buildGameGrid(_recentGames, theme),
            const SizedBox(height: 24),
          ],
        ],
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildGamesCarousel(List<Game> games, ThemeData theme) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildGameCard(game, theme, isLarge: true),
          );
        },
      ),
    );
  }

  Widget _buildGameGrid(List<Game> games, ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: games.map((game) => _buildGameCard(game, theme)).toList(),
    );
  }

  Widget _buildGameCard(Game game, ThemeData theme, {bool isLarge = false}) {
    final width = isLarge ? 120.0 : 80.0;
    final height = isLarge ? 160.0 : 110.0;
    final isFavorite = _favoriteGames
        .any((g) => g.igdbId == game.igdbId || g.name == game.name);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onGameSelected(game);
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Game Cover
              if (game.coverUrl != null)
                Positioned.fill(
                  child: Image.network(
                    game.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: theme.colorScheme.surface.withOpacity(0.5),
                        child: Icon(
                          Icons.gamepad,
                          size: isLarge ? 48 : 32,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  child: Center(
                    child: Icon(
                      Icons.gamepad,
                      size: isLarge ? 48 : 32,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Star button (top right)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    try {
                      final userNotifier =
                          ref.read(userNotifierProvider.notifier);
                      if (isFavorite) {
                        await userNotifier.removePinnedGame(game.name);
                        if (mounted) {
                          setState(() {
                            _favoriteGames.removeWhere((g) =>
                                g.igdbId == game.igdbId || g.name == game.name);
                          });
                        }
                      } else {
                        await userNotifier.addPinnedGame(game.toJson());
                        if (mounted) {
                          setState(() {
                            _favoriteGames.add(game);
                          });
                        }
                      }
                    } catch (e) {
                      debugPrint('Error toggling favorite: $e');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? Colors.amber : Colors.white,
                      size: isLarge ? 20 : 16,
                    ),
                  ),
                ),
              ),

              // Game Name
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  game.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isLarge ? 12 : 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
