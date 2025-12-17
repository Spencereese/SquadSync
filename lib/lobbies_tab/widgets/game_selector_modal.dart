import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../core/app_theme.dart';
import '../../domain/entities/game.dart';
import '../../presentation/notifiers/game_state_notifier.dart';
import '../../presentation/notifiers/user_notifier.dart';
import '../../widgets/game_search_delegate.dart';

/// Game selector modal with pinned games carousel
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

  List<Game> _pinnedGames = [];
  List<Game> _recentGames = [];
  bool _isLoading = true;

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
      // Get pinned games from user preferences
      final userState = ref.read(userNotifierProvider).value;
      if (userState?.pinnedGames != null && userState!.pinnedGames.isNotEmpty) {
        _pinnedGames = userState.pinnedGames
            .map((g) {
              try {
                return Game.fromCache(g);
              } catch (e) {
                debugPrint('Error parsing pinned game: $e');
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
            icon: const Icon(Icons.search),
            onPressed: () async {
              final game = await GameSearchDelegate.show(context, ref: ref);
              if (game != null && mounted) {
                widget.onGameSelected(game);
              }
            },
          ),
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
        // Pinned Games Carousel
        if (_pinnedGames.isNotEmpty) ...[
          _buildSectionHeader(theme, 'Pinned Games', Icons.push_pin),
          const SizedBox(height: 12),
          _buildPinnedGamesCarousel(theme),
          const SizedBox(height: 24),
        ],

        // Recent Games
        if (_recentGames.isNotEmpty) ...[
          _buildSectionHeader(theme, 'Recently Played', Icons.history),
          const SizedBox(height: 12),
          _buildGameGrid(_recentGames, theme),
          const SizedBox(height: 24),
        ],

        // Search Button
        _buildSearchButton(theme),
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

  Widget _buildPinnedGamesCarousel(ThemeData theme) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pinnedGames.length,
        itemBuilder: (context, index) {
          final game = _pinnedGames[index];
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
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
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

  Widget _buildSearchButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final game = await GameSearchDelegate.show(context, ref: ref);
          if (game != null && mounted) {
            widget.onGameSelected(game);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
          foregroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
          ),
        ),
        icon: const Icon(Icons.search),
        label: const Text(
          'Search All Games (IGDB)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
