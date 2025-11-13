import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../managers/user_manager.dart';
import '../services/igdb_auth_service.dart';
import 'game_platform_dialog.dart';

/// Screen for first-time users to select games they play
class AddGameScreen extends StatefulWidget {
  const AddGameScreen({super.key});

  @override
  State<AddGameScreen> createState() => _AddGameScreenState();
}

class _AddGameScreenState extends State<AddGameScreen> {
  final Set<String> _selectedGames = {};
  List<Map<String, dynamic>> _availableGames = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final igdbService = IgdbAuthService();
      // Load popular games that have cover images
      final games = await igdbService.searchGames('', limit: 50);

      // Filter games that have cover images and are recent/popular
      final filteredGames = games.where((game) {
        return game['coverUrl'] != null &&
            game['coverUrl'].toString().isNotEmpty &&
            game['name'] != null &&
            game['name'].toString().isNotEmpty;
      }).toList();

      if (mounted) {
        setState(() {
          _availableGames = filteredGames;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load games: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Games'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed:
                _selectedGames.isNotEmpty && !_isLoading ? _onContinue : null,
            child: Text(
              'Continue (${_selectedGames.length})',
              style: TextStyle(
                color: _selectedGames.isNotEmpty && !_isLoading
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading games...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
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
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadGames,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
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
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select the games you play to personalize your experience and find the best squads.',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Game selection grid
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _availableGames.length,
                          itemBuilder: (context, index) {
                            final game = _availableGames[index];
                            final isSelected =
                                _selectedGames.contains(game['slug']);

                            return _GameCard(
                              game: game,
                              isSelected: isSelected,
                              onTap: () => _onGameTap(game),
                            );
                          },
                        ),
                      ),
                    ),

                    // Skip option
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextButton(
                        onPressed: _onSkip,
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

    final userManager = Provider.of<UserManager>(context, listen: false);

    try {
      // Save selected games to pinned games
      for (final gameSlug in _selectedGames) {
        final game = _availableGames.firstWhere((g) => g['slug'] == gameSlug);
        await userManager.addPinnedGame(game);
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

  void _onSkip() {
    // Navigate to main app without saving games
    Navigator.of(context).pushReplacementNamed('/main');
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
