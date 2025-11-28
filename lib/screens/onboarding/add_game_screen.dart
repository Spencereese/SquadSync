import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/onboarding_service.dart';
import '../../presentation/notifiers/game_notifier.dart';

class AddGameScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const AddGameScreen({super.key, required this.onComplete});

  @override
  ConsumerState<AddGameScreen> createState() => _AddGameScreenState();
}

class _AddGameScreenState extends ConsumerState<AddGameScreen> {
  final TextEditingController _gameSearchController = TextEditingController();

  @override
  void dispose() {
    _gameSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingServiceProvider);
    final popularGamesAsync = ref.watch(gameNotifierProvider);
    final isValid = (onboardingState.value?.pinnedGames.length ?? 0) >= 1;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pin Your Favorite Games',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 16),
          TextField(
            controller: _gameSearchController,
            decoration: InputDecoration(
              labelText: 'Search games...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _searchGames,
              ),
            ),
            onSubmitted: (_) => _searchGames(),
          ).animate().slideX(begin: -0.2, duration: 400.ms),
          const SizedBox(height: 16),
          Expanded(
            child: popularGamesAsync.when(
              data: (state) => _buildGameList(
                  state.availableGames.map((g) => g.toJson()).toList(),
                  onboardingState.value?.pinnedGames ?? []),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(gameNotifierProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isValid)
            Text(
              'Pin at least 1 game to continue',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ).animate().fadeIn(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isValid ? () => _completeOnboarding(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Get Started'),
          ).animate().slideY(begin: 0.2, duration: 400.ms),
        ],
      ),
    );
  }

  void _searchGames() {
    HapticFeedback.lightImpact();
    if (_gameSearchController.text.isEmpty) return;
    // For now, just invalidate to refresh
    ref.invalidate(gameNotifierProvider);
  }

  Widget _buildGameList(List<Map<String, dynamic>> games,
      List<Map<String, dynamic>> pinnedGames) {
    return ListView.builder(
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        final isPinned = pinnedGames.any((g) => g['id'] == game['id']);
        return ListTile(
          title: Text(game['name']),
          trailing: IconButton(
            icon: Icon(isPinned ? Icons.star : Icons.star_border),
            onPressed: () => _togglePinGame(game),
          ),
        ).animate().fadeIn(delay: (index * 50).ms);
      },
    );
  }

  void _togglePinGame(Map<String, dynamic> game) {
    HapticFeedback.lightImpact();
    final onboardingService = ref.read(onboardingServiceProvider.notifier);
    final currentPinned =
        ref.read(onboardingServiceProvider).value?.pinnedGames ?? [];
    List<Map<String, dynamic>> newPinned;
    if (currentPinned.any((g) => g['id'] == game['id'])) {
      newPinned = currentPinned.where((g) => g['id'] != game['id']).toList();
    } else {
      newPinned = [...currentPinned, game];
    }
    onboardingService.updatePinnedGames(newPinned);
  }

  void _completeOnboarding(BuildContext context) {
    HapticFeedback.mediumImpact();
    widget.onComplete();
  }
}
