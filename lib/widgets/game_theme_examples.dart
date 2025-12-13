import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/controllers/game_theme_controller.dart';
import '../presentation/notifiers/game_notifier.dart';

/// Integration examples for GameThemeController
///
/// This file shows various ways to trigger and use dynamic themes

// EXAMPLE 1: Automatic theme sync (already integrated in app_widgets.dart)
// GameThemeSync.watch(ref) in SquadSyncMaterialApp automatically updates theme

// EXAMPLE 2: Manual theme update when user selects a game
class GameSelectionExample extends ConsumerWidget {
  const GameSelectionExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        // When user selects a game, this will trigger automatic theme update
        // via GameThemeSync.watch(ref) in app_widgets.dart
        // final gameNotifier = ref.read(gameNotifierProvider.notifier);

        // Example game data
        // final exampleGame = {
        //   'id': 1020,
        //   'name': 'Call of Duty: Warzone',
        //   'cover': {'url': 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1rbo.jpg'},
        // };

        // Setting currentGame will automatically trigger theme update
        // gameNotifier.setCurrentGame(Game.fromIgdb(exampleGame));

        // For this example, manually update theme
        await ref.read(gameThemeControllerProvider.notifier).updateGameTheme(
              gameId: '1020',
              gameName: 'Call of Duty: Warzone',
              coverImageUrl:
                  'https://images.igdb.com/igdb/image/upload/t_cover_big/co1rbo.jpg',
            );
      },
      child: const Text('Select Warzone'),
    );
  }
}

// EXAMPLE 3: Direct theme controller access
class DirectThemeUpdateExample extends ConsumerWidget {
  const DirectThemeUpdateExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Update theme with game data
        ElevatedButton(
          onPressed: () async {
            await ref
                .read(gameThemeControllerProvider.notifier)
                .updateGameTheme(
                  gameId: '1020',
                  gameName: 'Call of Duty: Warzone',
                  coverImageUrl:
                      'https://images.igdb.com/igdb/image/upload/t_cover_big/co1rbo.jpg',
                );
          },
          child: const Text('Apply Warzone Theme'),
        ),

        // Set custom colors manually
        ElevatedButton(
          onPressed: () async {
            await ref
                .read(gameThemeControllerProvider.notifier)
                .setCustomColors(
                  dominant: const Color(0xFF00FF41),
                  vibrant: const Color(0xFF39FF14),
                  accent: const Color(0xFF00CC33),
                );
          },
          child: const Text('Set Custom Green Theme'),
        ),

        // Reset to default
        ElevatedButton(
          onPressed: () async {
            await ref
                .read(gameThemeControllerProvider.notifier)
                .resetToDefault();
          },
          child: const Text('Reset to Default'),
        ),
      ],
    );
  }
}

// EXAMPLE 4: Access theme colors in widgets
class ThemeColorUsageExample extends ConsumerWidget {
  const ThemeColorUsageExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current theme colors
    final primaryColor = ref.watch(currentPrimaryColorProvider);
    final accentColor = ref.watch(currentAccentColorProvider);
    final dominantColor = ref.watch(currentDominantColorProvider);

    // Or get full theme state
    final themeState = ref.watch(gameThemeControllerProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            dominantColor.withOpacity(0.3),
            primaryColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor, width: 2),
      ),
      child: Column(
        children: [
          Text(
            'Current Game: ${themeState.currentGameName ?? 'None'}',
            style: TextStyle(color: primaryColor),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// EXAMPLE 5: Listen to theme changes
class ThemeChangeListenerExample extends ConsumerStatefulWidget {
  const ThemeChangeListenerExample({super.key});

  @override
  ConsumerState<ThemeChangeListenerExample> createState() =>
      _ThemeChangeListenerExampleState();
}

class _ThemeChangeListenerExampleState
    extends ConsumerState<ThemeChangeListenerExample> {
  @override
  void initState() {
    super.initState();
    // Setup listener for theme changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(
        gameThemeControllerProvider,
        (previous, next) {
          // Theme changed - you can trigger animations, haptics, etc.
          if (previous?.currentGameId != next.currentGameId) {
            debugPrint('Theme changed to: ${next.currentGameName}');

            // Example: Show snackbar when theme changes
            if (mounted && next.currentGameName != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Theme updated for ${next.currentGameName}'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: next.vibrantColor,
                ),
              );
            }
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// EXAMPLE 6: Conditional rendering based on theme state
class ThemeStateExample extends ConsumerWidget {
  const ThemeStateExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(gameThemeControllerProvider);

    if (themeState.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Extracting theme colors...'),
          ],
        ),
      );
    }

    if (themeState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: ${themeState.error}'),
            ElevatedButton(
              onPressed: () {
                ref.read(gameThemeControllerProvider.notifier).resetToDefault();
              },
              child: const Text('Use Default Theme'),
            ),
          ],
        ),
      );
    }

    return const Text('Theme ready!');
  }
}

// EXAMPLE 7: Integration with squad game selection
class LobbyGameThemeExample extends ConsumerWidget {
  final String gameName;

  const LobbyGameThemeExample({super.key, required this.gameName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameNotifierProvider);

    return gameState.when(
      data: (state) {
        // Find the game in available games
        final game = state.availableGames.firstWhere(
          (g) => g.name == gameName,
          orElse: () => throw Exception('Game not found'),
        );

        return ElevatedButton(
          onPressed: () async {
            // Update theme when entering squad for this game
            await ref
                .read(gameThemeControllerProvider.notifier)
                .updateGameTheme(
                  gameId: game.igdbId?.toString() ?? game.slug,
                  gameName: game.name,
                  coverImageUrl: game.coverUrl,
                );

            // Then navigate to squad screen
            // Navigator.push(...);
          },
          child: Text('Join ${game.name} Lobby'),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}

// EXAMPLE 8: Preset color picker for quick theme changes
class PresetColorPickerExample extends ConsumerWidget {
  const PresetColorPickerExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = [
      {'name': 'Warzone', 'color': const Color(0xFF00FF41)},
      {'name': 'Valorant', 'color': const Color(0xFFFF4655)},
      {'name': 'Apex Legends', 'color': const Color(0xFFFF6347)},
      {'name': 'Fortnite', 'color': const Color(0xFF00B4FF)},
      {'name': 'Default', 'color': const Color(0xFF00F5FF)},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: presets.map((preset) {
        final color = preset['color'] as Color;
        return InkWell(
          onTap: () async {
            await ref
                .read(gameThemeControllerProvider.notifier)
                .updateGameTheme(
                  gameId: preset['name'] as String,
                  gameName: preset['name'] as String,
                  coverImageUrl: null, // Will use preset
                );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                preset['name'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
