import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/game_manager.dart';
import '../managers/user_manager.dart';
import 'game_platform_dialog.dart';

/// Screen for first-time users to select games they play
class AddGameScreen extends StatefulWidget {
  const AddGameScreen({super.key});

  @override
  State<AddGameScreen> createState() => _AddGameScreenState();
}

class _AddGameScreenState extends State<AddGameScreen> {
  final Set<String> _selectedGames = {};

  @override
  Widget build(BuildContext context) {
    final gameManager = Provider.of<GameManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Games'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _selectedGames.isNotEmpty ? _onContinue : null,
            child: Text(
              'Continue (${_selectedGames.length})',
              style: TextStyle(
                color: _selectedGames.isNotEmpty
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      body: Column(
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

          // Game selection grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: gameManager.availableGames.length,
                itemBuilder: (context, index) {
                  final game = gameManager.availableGames[index];
                  final isSelected = _selectedGames.contains(game['id']);

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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onGameTap(Map<String, dynamic> game) async {
    final gameId = game['id'] as String;

    if (_selectedGames.contains(gameId)) {
      // Deselect game
      setState(() {
        _selectedGames.remove(gameId);
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
          _selectedGames.add(gameId);
        });
        // TODO: Store platform config for later use
      }
    }
  }

  void _onContinue() async {
    if (_selectedGames.isEmpty) return;

    final userManager = Provider.of<UserManager>(context, listen: false);
    final gameManager = Provider.of<GameManager>(context, listen: false);

    try {
      // Save selected games to pinned games
      for (final gameId in _selectedGames) {
        final game =
            gameManager.availableGames.firstWhere((g) => g['id'] == gameId);
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
              // Game icon placeholder (could be replaced with actual game icons)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.sports_esports,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
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
