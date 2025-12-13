import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/game.dart';
import '../../../widgets/game_selection_widget.dart';
import '../../../widgets/game_tile.dart';
import '../../notifiers/user_notifier.dart';
import '../onboarding_notifier.dart';

/// Onboarding game selection screen - delegates to GameSelectionWidget
///
/// Features:
/// - Multi-select up to 6 games
/// - Primary game designation (star badge)
/// - AI recommendations (A/B test variant B)
/// - Selected games chips with scroll
class GameSelectionScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const GameSelectionScreen({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<GameSelectionScreen> createState() =>
      _GameSelectionScreenState();
}

class _GameSelectionScreenState extends ConsumerState<GameSelectionScreen>
    with TickerProviderStateMixin {
  final ScrollController _selectedChipsController = ScrollController();

  List<Game> _selectedGames = [];
  String? _primaryGameSlug;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _selectedChipsController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onGamesUpdated(List<Game> games) {
    setState(() {
      _selectedGames = games;
    });

    // Update onboarding state
    ref.read(onboardingProvider.notifier).setGames(
          _selectedGames.map((g) => g.slug).toList(),
        );
  }

  void _onPrimaryGameChanged(String slug) {
    setState(() {
      _primaryGameSlug = slug;
    });
  }

  Future<void> _completeSelection() async {
    if (_selectedGames.isEmpty) return;

    HapticFeedback.heavyImpact();

    try {
      // Save to onboarding state
      ref.read(onboardingProvider.notifier).setGames(
            _selectedGames.map((g) => g.slug).toList(),
          );

      // Save to user notifier (for pinnedGames)
      final userNotifier = ref.read(userNotifierProvider.notifier);
      for (final game in _selectedGames) {
        await userNotifier.addPinnedGame(game.toJson());
      }

      // Call completion callback with mounted check
      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      debugPrint('Error saving selected games: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving games: $e'),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
    }
  }

  void _requestAIRecommendations() async {
    final onboardingState = ref.read(onboardingProvider);
    final callsign = onboardingState.callsign ?? 'Player';

    // Build user context for AI
    final context = '''
Callsign: $callsign
Already selected games: ${_selectedGames.map((g) => g.name).join(', ')}
Looking for ${_selectedGames.isEmpty ? 'first game recommendations' : 'additional games'}
''';

    await ref
        .read(onboardingProvider.notifier)
        .fetchGameRecommendations(context);
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SELECT YOUR GAMES',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.cyan,
                          letterSpacing: 3,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                      // AI Recommendations button
                      if (onboardingState.abTestVariant == 'B')
                        IconButton(
                          onPressed: onboardingState.isLoadingRecommendations
                              ? null
                              : _requestAIRecommendations,
                          icon: onboardingState.isLoadingRecommendations
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.cyan),
                                  ),
                                )
                              : const Icon(Icons.auto_awesome,
                                  color: Colors.cyan),
                          tooltip: 'Get AI Recommendations',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose up to 6 games',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.cyan.withOpacity(0.6),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            // AI Recommendations section (only for variant B)
            if (onboardingState.abTestVariant == 'B' &&
                onboardingState.aiRecommendedGames.isNotEmpty)
              _buildAIRecommendations(onboardingState),

            // Game selection widget (delegates to unified component)
            Expanded(
              child: SingleChildScrollView(
                child: GameSelectionWidget(
                  isOnboarding: true,
                  allowMultipleSelect: true,
                  maxSelections: 6,
                  initialSelectedGames: _selectedGames,
                  primaryGameSlug: _primaryGameSlug,
                  tileStyle: GameTileStyle.card,
                  onGamesSelected: _onGamesUpdated,
                  onPrimaryGameChanged: _onPrimaryGameChanged,
                  showSearchButton: true,
                  showPinnedGames: false,
                ),
              ),
            ),

            // Selected chips + Done button (fixed bottom)
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAIRecommendations(onboardingState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.cyan, size: 16),
              const SizedBox(width: 8),
              Text(
                'AI RECOMMENDATIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.cyan.withOpacity(0.8),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                onboardingState.aiRecommendedGames.map<Widget>((gameName) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.cyan.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gameName,
                      style: TextStyle(
                        color: Colors.cyan.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline,
                      color: Colors.cyan.withOpacity(0.6),
                      size: 14,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasSelection = _selectedGames.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border(
          top: BorderSide(
            color: Colors.cyan.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected chips
              if (hasSelection)
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    controller: _selectedChipsController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedGames.length,
                    itemBuilder: (context, index) {
                      final game = _selectedGames[index];
                      final isPrimary = game.slug == _primaryGameSlug;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildSelectedChip(game, isPrimary),
                      );
                    },
                  ),
                ),

              if (hasSelection) const SizedBox(height: 12),

              // Done button
              GestureDetector(
                onTap: hasSelection ? _completeSelection : null,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: hasSelection
                            ? const LinearGradient(
                                colors: [Colors.cyan, Colors.purpleAccent],
                              )
                            : null,
                        color:
                            hasSelection ? null : Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: hasSelection
                            ? [
                                BoxShadow(
                                  color: Colors.cyan
                                      .withOpacity(_pulseAnimation.value * 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          hasSelection
                              ? 'DONE (${_selectedGames.length}/6)'
                              : 'SELECT AT LEAST 1 GAME',
                          style: TextStyle(
                            color: hasSelection ? Colors.white : Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChip(Game game, bool isPrimary) {
    return GameTile(
      game: game,
      isPrimary: isPrimary,
      style: GameTileStyle.chip,
      onTap: () {
        // Remove game from selection
        setState(() {
          _selectedGames.removeWhere((g) => g.slug == game.slug);
          if (_primaryGameSlug == game.slug) {
            _primaryGameSlug =
                _selectedGames.isNotEmpty ? _selectedGames.first.slug : null;
          }
        });
        _onGamesUpdated(_selectedGames);
      },
      onLongPress: () {
        _onPrimaryGameChanged(game.slug);
      },
    );
  }
}
