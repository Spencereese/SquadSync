import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class GameSelectionWidget extends ConsumerWidget {
  const GameSelectionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameManager = ref.watch(gameManagerProvider);
    final availableGames = gameManager.availableGames
        .where((game) => !gameManager.isGameHidden(game['name']))
        .toList();
    final currentGame = gameManager.currentGame;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Game Select',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
              const SizedBox(height: 16),
              if (availableGames.isEmpty)
                const Center(
                  child: Text('No games available'),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: availableGames.map((game) {
                    final isSelected = currentGame?['name'] == game['name'];
                    return _GameCard(
                      game: game,
                      isSelected: isSelected,
                      onTap: () => gameManager.selectGame(game),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getGameIcon(game['name'] as String? ?? ''),
              size: 40,
              color: isSelected ? Colors.white : Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              game['name'] as String? ?? 'Unknown',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getGameIcon(String gameName) {
    switch (gameName.toLowerCase()) {
      case 'warzone':
        return Icons.public;
      case 'modern warfare':
        return Icons.gps_fixed;
      case 'black ops':
        return Icons.visibility;
      default:
        return Icons.games;
    }
  }
}
