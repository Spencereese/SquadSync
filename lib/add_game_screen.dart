import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'managers/game_manager.dart';
import 'managers/user_manager.dart';
import 'game_platform_dialog.dart';

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
    final userManager = Provider.of<UserManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Games'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Choose the games you play to personalize your experience and get better recommendations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: gameManager.availableGames.length,
              itemBuilder: (context, index) {
                final game = gameManager.availableGames[index];
                final gameName = game['name'] as String;
                final isSelected = _selectedGames.contains(gameName);

                return _GameCard(
                  game: game,
                  isSelected: isSelected,
                  onTap: () => _onGameTap(gameName),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedGames.isNotEmpty
                    ? () => _onContinue(userManager)
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _selectedGames.isNotEmpty
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onGameTap(String gameName) async {
    // Show platform configuration dialog
    final config = await showDialog<GamePlatformConfig>(
      context: context,
      builder: (context) => GamePlatformDialog(gameName: gameName),
    );

    if (config != null && config.isValid && mounted) {
      setState(() {
        if (_selectedGames.contains(gameName)) {
          _selectedGames.remove(gameName);
        } else {
          _selectedGames.add(gameName);
        }
      });
    }
  }

  Future<void> _onContinue(UserManager userManager) async {
    // Get gameManager before async operation to avoid BuildContext issues
    final gameManager = Provider.of<GameManager>(context, listen: false);

    for (final gameName in _selectedGames) {
      // Find the full game object from gameManager
      final game = gameManager.availableGames.firstWhere(
        (g) => g['name'] == gameName,
        orElse: () => {'name': gameName}, // Fallback if not found
      );
      await userManager.addPinnedGame(game);
    }

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }
}

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
    final gameName = game['name'] as String;
    final iconPath = game['icon'] as String?;

    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconPath != null)
                Image.asset(
                  'assets/images/$iconPath',
                  width: 48,
                  height: 48,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.games,
                    size: 48,
                    color: Colors.grey,
                  ),
                )
              else
                const Icon(
                  Icons.games,
                  size: 48,
                  color: Colors.grey,
                ),
              const SizedBox(height: 8),
              Text(
                gameName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
