import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../domain/entities/game.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../presentation/notifiers/game_notifier.dart';
import '../widgets/game_selection_widget.dart';
import '../widgets/game_tile.dart';

/// Screen for first-time users to select games they play
/// Now uses unified GameSelectionWidget with Material 3 theme
class AddGameScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;

  const AddGameScreen({super.key, this.onComplete});

  @override
  ConsumerState<AddGameScreen> createState() => _AddGameScreenState();
}

class _AddGameScreenState extends ConsumerState<AddGameScreen> {
  final List<Game> _selectedGames = [];

  @override
  void initState() {
    super.initState();
    // Fetch popular games on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameNotifierProvider.notifier).loadPopularGames();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neonColor = theme.colorScheme.primary;
    final gameStateAsync = ref.watch(gameNotifierProvider);
    final isLoading = gameStateAsync.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Column(
          children: [
            // Glassmorphic app bar
            GlassmorphicContainer(
              neonColor: neonColor,
              blur: 20,
              borderRadius: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Close button
                    IconButton(
                      icon: Icon(Icons.close, color: neonColor),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (widget.onComplete != null) {
                          widget.onComplete!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      tooltip: 'Cancel',
                    ),
                    const SizedBox(width: 12),
                    // Title
                    Expanded(
                      child: Text(
                        'SELECT YOUR GAMES',
                        style: GoogleFonts.orbitron(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: neonColor,
                          letterSpacing: 1.5,
                          shadows: neonColor.neonGlow(
                            blur: 10,
                            opacity: 0.3,
                          ),
                        ),
                      ),
                    ),
                    // Continue button
                    NeonPulseButton(
                      onPressed: _selectedGames.isNotEmpty && !isLoading
                          ? _onContinue
                          : null,
                      neonColor: neonColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Continue (${_selectedGames.length})',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Game selection widget
            Expanded(
              child: GameSelectionWidget(
                allowMultipleSelect: true,
                showSearchButton: true,
                showPinnedGames: false,
                tileStyle: GameTileStyle.grid,
                initialSelectedGames: _selectedGames,
                onGamesSelected: (games) {
                  setState(() {
                    _selectedGames.clear();
                    _selectedGames.addAll(games);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onContinue() async {
    if (_selectedGames.isEmpty) return;

    HapticFeedback.mediumImpact();
    final userNotifier = ref.read(userNotifierProvider.notifier);

    try {
      // Save selected games to pinned games
      for (final game in _selectedGames) {
        await userNotifier.addPinnedGame(game.toJson());
      }

      if (mounted) {
        // Check if this is onboarding (has onComplete callback)
        if (widget.onComplete != null) {
          widget.onComplete!();
        } else {
          // Go back to previous screen (squad lobbies)
          Navigator.of(context).pop();

          // Show success message with themed snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_selectedGames.length} game${_selectedGames.length == 1 ? '' : 's'} added to your collection!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save games: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
