import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/user_notifier.dart';
import '../../providers.dart';

class PinGameDialog extends ConsumerStatefulWidget {
  const PinGameDialog({super.key});

  @override
  ConsumerState<PinGameDialog> createState() => _PinGameDialogState();
}

class _PinGameDialogState extends ConsumerState<PinGameDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchGames() {
    if (_searchController.text.isEmpty) return;

    ref.read(gameManagerProvider).fetchGamesFromIGDB(_searchController.text);
  }

  void _togglePinGame(Map<String, dynamic> game) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(userNotifierProvider.notifier).pinGame(game);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${game['name'] ?? 'Game'} pinned successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pin game: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameStateAsync = ref.watch(gameManagerProvider);
    final userStateAsync = ref.watch(userNotifierProvider);
    final pinnedGames = userStateAsync.maybeWhen(
      data: (userState) => userState?.pinnedGames ?? <Map<String, dynamic>>[],
      orElse: () => <Map<String, dynamic>>[],
    );

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
              child: gameStateAsync.isOffline
                  ? Banner(
                      message: 'Using offline cache',
                      location: BannerLocation.topEnd,
                      child: _buildGameList(gameStateAsync.games, pinnedGames),
                    )
                  : _buildGameList(gameStateAsync.games, pinnedGames),
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
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameList(List<Map<String, dynamic>> games,
      List<Map<String, dynamic>> pinnedGames) {
    if (games.isEmpty) {
      return const Center(
        child: Text('Search for games to pin them for quick access'),
      );
    }

    return ListView.builder(
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        final isPinned = pinnedGames.any((g) => g['id'] == game['id']);

        return ListTile(
          title: Text(game['name'] ?? 'Unknown Game'),
          trailing: IconButton(
            icon: Icon(
              isPinned ? Icons.star : Icons.star_border,
              color: isPinned ? Colors.amber : null,
            ),
            onPressed: () => _togglePinGame(game),
          ),
        );
      },
    );
  }
}
