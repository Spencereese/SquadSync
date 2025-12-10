import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/async_value_widget.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../presentation/notifiers/game_notifier.dart';

/// Screen for first-time users to select games they play
class AddGameScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;

  const AddGameScreen({super.key, this.onComplete});

  @override
  ConsumerState<AddGameScreen> createState() => _AddGameScreenState();
}

class _AddGameScreenState extends ConsumerState<AddGameScreen> {
  final Map<String, Map<String, dynamic>> _selectedGames = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    // Fetch popular games on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameNotifierProvider.notifier).loadPopularGames();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameStateAsync = ref.watch(gameNotifierProvider);
    final isLoading = gameStateAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Games'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (widget.onComplete != null) {
              // In setup flow, call onComplete to continue without selecting games
              widget.onComplete!();
            } else {
              Navigator.of(context).pop();
            }
          },
          tooltip: 'Cancel',
        ),
        actions: [
          TextButton(
            onPressed:
                _selectedGames.isNotEmpty && !isLoading ? _onContinue : null,
            child: Text(
              'Continue (${_selectedGames.length})',
              style: TextStyle(
                color: _selectedGames.isNotEmpty && !isLoading
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search games...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
                if (_searchQuery.isNotEmpty) {
                  ref
                      .read(gameNotifierProvider.notifier)
                      .searchGames(_searchQuery)
                      .then((result) {
                    result.when(
                      data: (games) {
                        if (mounted) {
                          setState(() {
                            _searchResults =
                                games.map((g) => g.toJson()).toList();
                          });
                        }
                      },
                      error: (error, stack) {
                        // Optionally show error
                        if (mounted) {
                          setState(() {
                            _searchResults = [];
                          });
                        }
                      },
                      loading: () {},
                    );
                  });
                } else {
                  // Don't clear search results, let AsyncValueWidget show availableGames
                  // by keeping _searchQuery empty
                }
              },
            ),
          ),
          // Game content
          Expanded(
            child: AsyncValueWidget<GameState>(
              value: gameStateAsync,
              data: (gameState) => _buildGameContent(
                _searchQuery.isNotEmpty
                    ? _searchResults
                    : gameState.availableGames
                        .map((game) => game.toJson())
                        .toList(),
              ),
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading games...'),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'API error: ${error.toString()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(gameNotifierProvider.notifier)
                            .loadPopularGames();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent(List<Map<String, dynamic>> games) {
    // Filter games that have valid data (allow games without covers to show fallback icon)
    final allGames = games.where((game) {
      final hasName =
          game['name'] != null && game['name'].toString().isNotEmpty;
      return hasName;
    }).toList();

    // Reduced logging - only log once on significant change
    if (allGames.isEmpty || games.isEmpty) {
      debugPrint(
          'AddGameScreen: Building content with ${allGames.length} games (${games.length} total before filtering)');
    }

    // Separate popular games (first 10) from others
    final popularGames = allGames.take(10).toList();
    final otherGames = allGames.skip(10).toList();

    // Filter games based on search query
    final filteredPopularGames = _searchQuery.isEmpty
        ? popularGames
        : popularGames
            .where((game) =>
                game['name'].toString().toLowerCase().contains(_searchQuery))
            .toList();

    final filteredOtherGames = _searchQuery.isEmpty
        ? otherGames
        : otherGames
            .where((game) =>
                game['name'].toString().toLowerCase().contains(_searchQuery))
            .toList();

    return CustomScrollView(
      slivers: [
        // Popular Games Section
        if (filteredPopularGames.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Popular Games',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredPopularGames.length,
                itemBuilder: (context, index) {
                  final game = filteredPopularGames[index];
                  final gameId =
                      (game['igdbId'] ?? game['slug'])?.toString() ?? '';
                  final isSelected = _selectedGames.containsKey(gameId);
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    child: _GameCard(
                      game: game,
                      isSelected: isSelected,
                      onTap: () => _onGameTap(game),
                      isHorizontal: true,
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // All Games Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              filteredPopularGames.isEmpty ? 'All Games' : 'More Games',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Games Grid
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final game = filteredOtherGames[index];
                final gameId =
                    (game['igdbId'] ?? game['slug'])?.toString() ?? '';
                final isSelected = _selectedGames.containsKey(gameId);
                return _GameCard(
                  game: game,
                  isSelected: isSelected,
                  onTap: () => _onGameTap(game),
                  isHorizontal: false,
                );
              },
              childCount: filteredOtherGames.length,
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  void _onGameTap(Map<String, dynamic> game) async {
    final gameId = (game['igdbId'] ?? game['slug'])?.toString() ?? '';

    if (_selectedGames.containsKey(gameId)) {
      // Deselect game
      setState(() {
        _selectedGames.remove(gameId);
      });
    } else {
      // Select game directly without configuration
      setState(() {
        _selectedGames[gameId] = game;
      });
    }
  }

  void _onContinue() async {
    if (_selectedGames.isEmpty) return;

    final gameStateAsync = ref.read(gameNotifierProvider);
    final gameState = gameStateAsync.value;
    if (gameState == null) return;

    final userNotifier = ref.read(userNotifierProvider.notifier);

    try {
      // Save selected games to pinned games
      for (final game in _selectedGames.values) {
        await userNotifier.addPinnedGame(game);
      }

      if (mounted) {
        // Check if this is onboarding (has onComplete callback)
        if (widget.onComplete != null) {
          widget.onComplete!();
        } else {
          // Go back to previous screen (squad lobbies)
          Navigator.of(context).pop();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${_selectedGames.length} game${_selectedGames.length == 1 ? '' : 's'} added to your collection!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save games: $e')),
        );
      }
    }
  }
}

/// Game card widget for the selection grid
class _GameCard extends StatelessWidget {
  final Map<String, dynamic> game;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isHorizontal;

  const _GameCard({
    required this.game,
    required this.isSelected,
    required this.onTap,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      // Horizontal layout for popular games - full image with text underneath
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Full image background
                Positioned.fill(
                  child: game['coverUrl'] != null
                      ? CachedNetworkImage(
                          imageUrl: game['coverUrl'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: 32,
                            ),
                          ),
                        )
                      : Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Icon(
                            Icons.sports_esports,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 32,
                          ),
                        ),
                ),
                // Gradient overlay for text readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                // Game name at bottom
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    game['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Selection indicator
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Vertical layout for grid - card with image and text
    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Larger image at top
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: game['coverUrl'] != null
                      ? CachedNetworkImage(
                          imageUrl: game['coverUrl'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: 32,
                            ),
                          ),
                        )
                      : Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Icon(
                            Icons.sports_esports,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 32,
                          ),
                        ),
                ),
              ),
            ),
            // Game name below image
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        game['name'] as String,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 4),
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
