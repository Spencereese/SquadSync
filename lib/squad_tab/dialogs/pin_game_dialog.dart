import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../managers/game_manager.dart';
import '../../widgets/async_value_widget.dart';
import '../../providers.dart' as providers;

class PinGameDialog extends ConsumerStatefulWidget {
  const PinGameDialog({super.key});

  @override
  ConsumerState<PinGameDialog> createState() => _PinGameDialogState();
}

class _PinGameDialogState extends ConsumerState<PinGameDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _pinnedGames = [];

  @override
  void initState() {
    super.initState();
    // Load current pinned games
    final userManager = ref.read(providers.userManagerProvider);
    _pinnedGames = List.from(userManager.pinnedGames);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchGames() {
    if (_searchController.text.isEmpty) return;

    ref
        .read(gameManagerProvider.notifier)
        .fetchGamesFromIGDB(_searchController.text);
  }

  void _togglePinGame(Map<String, dynamic> game) {
    setState(() {
      if (_pinnedGames.any((g) => g['id'] == game['id'])) {
        _pinnedGames.removeWhere((g) => g['id'] == game['id']);
      } else {
        _pinnedGames.add(game);
      }
    });
  }

  void _savePinnedGames() async {
    final userManager = ref.read(providers.userManagerProvider);
    // Update the user manager's pinned games
    userManager.pinnedGames.clear();
    userManager.pinnedGames.addAll(_pinnedGames);
    // Save to Firestore
    await userManager.savePinnedGamesToFirestore();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Games pinned successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameStateAsync = ref.watch(gameManagerProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pin Your Favorite Games',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search games...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchGames,
                ),
              ),
              onSubmitted: (_) => _searchGames(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AsyncValueWidget<GameState>(
                value: gameStateAsync,
                data: (gameState) => gameState.isOffline
                    ? Banner(
                        message: 'Using offline cache',
                        location: BannerLocation.topEnd,
                        child: _buildGameList(gameState.games),
                      )
                    : _buildGameList(gameState.games),
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Searching games...'),
                    ],
                  ),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Search failed: ${error.toString()}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _searchGames,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _savePinnedGames,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameList(List<Map<String, dynamic>> games) {
    if (games.isEmpty) {
      return const Center(
        child: Text('Search for games to pin them for quick access'),
      );
    }

    return ListView.builder(
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        final isPinned = _pinnedGames.any((g) => g['id'] == game['id']);

        return ListTile(
          title: Text(game['name'] ?? 'Unknown Game'),
          trailing: IconButton(
            icon: Icon(
              isPinned ? Icons.star : Icons.star_border,
              color: isPinned ? Colors.amber : null,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _togglePinGame(game);
            },
          ),
        );
      },
    );
  }
}
