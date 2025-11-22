import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/async_value_widget.dart';
import '../providers/user_notifier.dart';
import '../managers/game_manager.dart';
import 'game_platform_dialog.dart';

/// Screen for first-time users to select games they play
class AddGameScreen extends ConsumerStatefulWidget {
  const AddGameScreen({super.key});

  @override
  ConsumerState<AddGameScreen> createState() => _AddGameScreenState();
}

class _AddGameScreenState extends ConsumerState<AddGameScreen> {
  final Set<String> _selectedGames = {};

  @override
  void initState() {
    super.initState();
    // Fetch popular games on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameManagerProvider.notifier).fetchGamesFromIGDB('');
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameStateAsync = ref.watch(gameManagerProvider);
    final isLoading = gameStateAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Games'),
        automaticallyImplyLeading: false,
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
      body: AsyncValueWidget<GameState>(
        value: gameStateAsync,
        data: (gameState) => _buildGameList(gameState.games),
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
                  ref.read(gameManagerProvider.notifier).fetchGamesFromIGDB('');
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameList(List<Map<String, dynamic>> games) {
    // Filter games that have cover images
    final filteredGames = games.where((game) {
      return game['coverUrl'] != null &&
          game['coverUrl'].toString().isNotEmpty &&
          game['name'] != null &&
          game['name'].toString().isNotEmpty;
    }).toList();

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.games,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to SquadSync!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Select the games you play to personalize your experience and find the best squads.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // Game list
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: filteredGames.length,
            itemBuilder: (context, index) {
              final game = filteredGames[index];
              final isSelected = _selectedGames.contains(game['slug']);
              return _GameCard(
                game: game,
                isSelected: isSelected,
                onTap: () => _onGameTap(game),
              );
            },
          ),
        ),
      ],
    );
  }

  void _onGameTap(Map<String, dynamic> game) async {
    final gameSlug = game['slug'] as String;

    if (_selectedGames.contains(gameSlug)) {
      // Deselect game
      setState(() {
        _selectedGames.remove(gameSlug);
      });
    } else {
      // Select game and show platform configuration
      final result = await showDialog<GamePlatformConfig?>(
        context: context,
        barrierDismissible: false,
        builder: (context) => GamePlatformDialog(game: game),
      );

      if (result != null && mounted) {
        setState(() {
          _selectedGames.add(gameSlug);
        });
        // TODO: Store platform config for later use
      }
    }
  }

  void _onContinue() async {
    if (_selectedGames.isEmpty) return;

    final gameState = ref.read(gameManagerProvider).value;
    if (gameState == null) return;

    final userNotifier = ref.read(userNotifierProvider.notifier);

    try {
      // Save selected games to pinned games
      for (final gameSlug in _selectedGames) {
        final game = gameState.games.firstWhere((g) => g['slug'] == gameSlug);
        await userNotifier.addPinnedGame(game);
      }

      if (mounted) {
        // Navigate to main app
        Navigator.of(context).pushReplacementNamed('/main');
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

  const _GameCard({
    required this.game,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Game cover image
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
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
                              size: 24,
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
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                game['name'] as String,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
    );
  }
}
