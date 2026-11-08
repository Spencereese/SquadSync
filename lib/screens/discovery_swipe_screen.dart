import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../domain/entities/lobby.dart';
import '../presentation/notifiers/discovery_notifier.dart';
import '../presentation/notifiers/lobby_notifier.dart' as ln;
import '../services/auth_service_supabase.dart';
import '../services/discovery_swipe_gate.dart';
import '../services/matchmaking_queue_machine.dart';
import '../widgets/discovery_swipe_gate.dart';
import '../widgets/glass_lobby_card.dart';

/// Gated fill-swipe for a squad looking for a fill.
///
/// Not a public Tinder-style launch. The existing card stub is shown only
/// when looking-for-fill AND a squad vouch are both true; otherwise a
/// clear gate / empty state.
class DiscoverySwipeScreen extends ConsumerStatefulWidget {
  const DiscoverySwipeScreen({super.key, this.gateOverride});

  /// Tests inject a resolved gate so auth / lobby / LFG stay unhit.
  final DiscoverySwipeGate? gateOverride;

  @override
  ConsumerState<DiscoverySwipeScreen> createState() =>
      _DiscoverySwipeScreenState();
}

class _DiscoverySwipeScreenState extends ConsumerState<DiscoverySwipeScreen>
    with TickerProviderStateMixin {
  // Swipe tracking
  Offset _dragPosition = Offset.zero;
  double _dragDistance = 0;
  double _rotation = 0;
  bool _isDragging = false;

  // Auto-play timer
  Timer? _autoPlayTimer;
  static const _autoPlayDuration = Duration(seconds: 8);

  // Confetti controller
  late ConfettiController _confettiController;

  // Animation controllers
  late AnimationController _swipeAwayController;
  late AnimationController _neonIntensityController;

  // Current card index
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _swipeAwayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _neonIntensityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 0,
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _confettiController.dispose();
    _swipeAwayController.dispose();
    _neonIntensityController.dispose();
    super.dispose();
  }

  DiscoverySwipeGate _liveGate() {
    final override = widget.gateOverride;
    if (override != null) return override;
    final uid = AuthServiceSupabase().currentUser?.id ?? '';
    final lobby = ref.watch(ln.lobbyNotifierProvider).valueOrNull?.currentLobby;
    final lfg = MatchmakingQueueTracker.instance.stateFor(uid);
    return resolveDiscoverySwipeGateFromContext(
      userId: uid,
      lfg: lfg,
      lobby: lobby,
    );
  }

  void _syncAutoPlay(bool gateOpen) {
    if (!gateOpen) {
      _autoPlayTimer?.cancel();
      return;
    }
    if (_autoPlayTimer?.isActive ?? false) return;
    _startAutoPlayTimer();
  }

  void _startAutoPlayTimer() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(_autoPlayDuration, () {
      if (mounted && !_isDragging) {
        _autoSwipeRight();
      }
    });
  }

  void _resetAutoPlayTimer() {
    _startAutoPlayTimer();
  }

  Future<void> _autoSwipeRight() async {
    final lobbies = ref.read(publicLobbiesProvider).value ?? [];
    if (lobbies.isEmpty) return;

    // Get Grok's best suggestion (for now, just use current top card)
    await _swipeRight(animated: true);
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragPosition = Offset.zero;
      _dragDistance = 0;
      _rotation = 0;
    });

    _neonIntensityController.animateTo(0.3);
    _autoPlayTimer?.cancel();
    HapticFeedback.lightImpact();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition += details.delta;
      _dragDistance = _dragPosition.distance;
      _rotation = (_dragPosition.dx / 1000).clamp(-0.3, 0.3);
    });

    // Intensify neon as drag increases
    final intensity = (_dragDistance / 200).clamp(0.0, 1.0);
    _neonIntensityController.value = intensity;
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.3;

    if (_dragDistance > threshold) {
      // Swipe threshold reached
      if (_dragPosition.dx > 0) {
        _swipeRight();
      } else {
        _swipeLeft();
      }
    } else {
      // Return to center
      _resetCardPosition();
    }
  }

  Future<void> _swipeRight({bool animated = false}) async {
    HapticFeedback.mediumImpact();

    if (animated) {
      setState(() {
        _dragPosition = Offset(MediaQuery.of(context).size.width * 1.5, -100);
        _rotation = 0.3;
      });
    }

    await _animateCardAway();
    await _joinLobby();
    _showConfetti();

    setState(() {
      _currentIndex++;
      _resetCardPosition();
    });

    _resetAutoPlayTimer();
  }

  Future<void> _swipeLeft() async {
    HapticFeedback.lightImpact();

    setState(() {
      _dragPosition = Offset(-MediaQuery.of(context).size.width * 1.5, -100);
      _rotation = -0.3;
    });

    await _animateCardAway();

    setState(() {
      _currentIndex++;
      _resetCardPosition();
    });

    _resetAutoPlayTimer();
  }

  Future<void> _superLike() async {
    HapticFeedback.heavyImpact();

    setState(() {
      _dragPosition = Offset(0, -MediaQuery.of(context).size.height * 1.2);
      _rotation = 0;
    });

    await _animateCardAway();
    await _joinLobby(instant: true);
    _showConfetti();

    setState(() {
      _currentIndex++;
      _resetCardPosition();
    });

    _resetAutoPlayTimer();
  }

  Future<void> _animateCardAway() async {
    await _swipeAwayController.forward();
    _swipeAwayController.reset();
  }

  void _resetCardPosition() {
    setState(() {
      _isDragging = false;
      _dragPosition = Offset.zero;
      _dragDistance = 0;
      _rotation = 0;
    });
    _neonIntensityController.animateTo(0);
  }

  Future<void> _joinLobby({bool instant = false}) async {
    final lobbies = ref.read(publicLobbiesProvider).value ?? [];

    if (_currentIndex < lobbies.length) {
      final lobby = lobbies[_currentIndex];

      // TODO: Call actual join lobby API
      // await ref.read(discoveryNotifierProvider.notifier).joinLobby(lobby.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              instant
                  ? '⚡ Super Joined ${lobby.name}!'
                  : '✨ Joined ${lobby.name}!',
              style: GoogleFonts.orbitron(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  void _showConfetti() {
    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    final tracker = MatchmakingQueueTracker.instance;
    return AnimatedBuilder(
      animation: tracker,
      builder: (context, _) {
        final gate = _liveGate();
        _syncAutoPlay(gate.canShowSwipe);
        if (!gate.canShowSwipe) {
          return DiscoverySwipeGatePanel(gate: gate);
        }
        return _buildSwipeSurface(context);
      },
    );
  }

  Widget _buildSwipeSurface(BuildContext context) {
    final theme = Theme.of(context);
    final lobbiesAsync = ref.watch(publicLobbiesProvider);

    return Scaffold(
      key: kDiscoverySwipeSurfaceKey,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'DISCOVER SQUADS',
          style: GoogleFonts.orbitron(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0B0E14),
                  Color(0xFF14181F),
                  Color(0xFF0B0E14),
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: lobbiesAsync.when(
              data: (lobbies) {
                final visibleLobbies =
                    lobbies.skip(_currentIndex).take(4).toList();

                if (visibleLobbies.isEmpty) {
                  return _buildEmptyState(theme);
                }

                return _buildCardStack(visibleLobbies, theme);
              },
              loading: () => _buildLoadingState(theme),
              error: (error, stack) => _buildErrorState(theme, error),
            ),
          ),

          // Action buttons overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: _buildActionButtons(theme),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2, // Down
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.3,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
                theme.colorScheme.tertiary,
                Colors.cyan,
                Colors.purple,
                Colors.pink,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack(List<Lobby> lobbies, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Stack(
        children: [
          // Background cards (4th, 3rd, 2nd) with parallax
          ...List.generate(
            math.min(3, lobbies.length - 1),
            (index) => _buildBackgroundCard(
              lobbies[index + 1],
              index + 1,
              theme,
            ),
          ).reversed,

          // Top card (draggable)
          if (lobbies.isNotEmpty) _buildTopCard(lobbies[0], theme),
        ],
      ),
    );
  }

  Widget _buildBackgroundCard(Lobby lobby, int depth, ThemeData theme) {
    // Parallax effect: cards further back are smaller and offset upward
    final scale = 1.0 - (depth * 0.05);
    final offsetY = depth * 12.0;
    final opacity = 1.0 - (depth * 0.2);

    return Transform.scale(
      scale: scale,
      child: Transform.translate(
        offset: Offset(0, -offsetY),
        child: Opacity(
          opacity: opacity,
          child: IgnorePointer(
            child: GlassLobbyCard(
              squad: lobby,
              gameCoverUrl: null, // TODO: Get from IGDB
              gamePrimaryColor: theme.colorScheme.primary,
              heroTag: 'squad_bg_${lobby.id}_$depth',
              showPeacockTimer: lobby.spotTimers.any((timer) => timer != null),
              peacockProgress: 0.5, // TODO: Calculate actual progress
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (depth * 50).ms)
        .slideY(begin: 0.1, duration: 400.ms, delay: (depth * 50).ms);
  }

  Widget _buildTopCard(Lobby lobby, ThemeData theme) {
    final neonColor = theme.colorScheme.primary;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onDoubleTap: _superLike,
      child: AnimatedBuilder(
        animation:
            Listenable.merge([_swipeAwayController, _neonIntensityController]),
        builder: (context, child) {
          final swipeProgress = _swipeAwayController.value;
          final position = _dragPosition * (1 + swipeProgress * 2);
          final rotation = _rotation * (1 + swipeProgress);
          final neonIntensity = _neonIntensityController.value;

          return Transform.translate(
            offset: position,
            child: Transform.rotate(
              angle: rotation,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: neonColor.neonGlow(
                    blur: 25 + (neonIntensity * 40),
                    spread: 2 + (neonIntensity * 4),
                    opacity: 0.4 + (neonIntensity * 0.4),
                  ),
                ),
                child: Stack(
                  children: [
                    GlassLobbyCard(
                      squad: lobby,
                      gameCoverUrl: null, // TODO: Get from IGDB
                      gamePrimaryColor: neonColor,
                      heroTag: 'squad_${lobby.id}',
                      showPeacockTimer:
                          lobby.spotTimers.any((timer) => timer != null),
                      peacockProgress: 0.5, // TODO: Calculate actual progress
                      onTap: () {
                        // Navigate to detail on tap (without swiping)
                        if (!_isDragging && _dragDistance < 10) {
                          _navigateToDetail(lobby);
                        }
                      },
                    ),

                    // Swipe direction indicator
                    if (_isDragging && _dragDistance > 50)
                      _buildSwipeIndicator(neonColor),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwipeIndicator(Color neonColor) {
    final isRight = _dragPosition.dx > 0;
    final opacity = (_dragDistance / 200).clamp(0.0, 1.0);

    return Positioned(
      top: 40,
      left: isRight ? null : 40,
      right: isRight ? 40 : null,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isRight
                ? Colors.green.withOpacity(0.9)
                : Colors.red.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: isRight ? Colors.green : Colors.red,
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Text(
            isRight ? 'JOIN' : 'PASS',
            style: GoogleFonts.orbitron(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    )
        .animate()
        .scale(begin: const Offset(0.8, 0.8))
        .shake(hz: 2, curve: Curves.easeInOut);
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pass button
          _buildActionButton(
            icon: Icons.close_rounded,
            color: Colors.red,
            size: 60,
            onPressed: _swipeLeft,
            label: 'PASS',
          ),

          // Super like button
          _buildActionButton(
            icon: Icons.star_rounded,
            color: theme.colorScheme.primary,
            size: 70,
            onPressed: _superLike,
            label: 'SUPER',
            isPrimary: true,
          ),

          // Like/Join button
          _buildActionButton(
            icon: Icons.favorite_rounded,
            color: Colors.green,
            size: 60,
            onPressed: () => _swipeRight(),
            label: 'JOIN',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onPressed,
    required String label,
    bool isPrimary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: color,
                width: isPrimary ? 3 : 2,
              ),
              boxShadow: color.neonGlow(
                blur: isPrimary ? 30 : 20,
                opacity: isPrimary ? 0.6 : 0.4,
              ),
            ),
            child: Icon(
              icon,
              size: size * 0.5,
              color: color,
            ),
          )
              .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              )
              .scale(
                begin: const Offset(1.0, 1.0),
                end: Offset(isPrimary ? 1.1 : 1.05, isPrimary ? 1.1 : 1.05),
                duration: isPrimary ? 1500.ms : 2000.ms,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated turkey
          const Text(
            '🦃',
            style: TextStyle(fontSize: 120),
          )
              .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              )
              .rotate(
                begin: -0.1,
                end: 0.1,
                duration: 1500.ms,
                curve: Curves.easeInOut,
              )
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.05, 1.05),
                duration: 2000.ms,
              ),

          const SizedBox(height: 32),

          GlassmorphicContainer(
            padding: const EdgeInsets.all(32),
            borderRadius: 24,
            child: Column(
              children: [
                Text(
                  'No lobbies right now',
                  style: GoogleFonts.orbitron(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Be the first to create one!',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to create lobby
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'CREATE SQUAD',
                    style: GoogleFonts.orbitron(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, duration: 600.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          )
              .animate(
                onPlay: (controller) => controller.repeat(),
              )
              .shimmer(duration: 1500.ms, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Finding lobbies...',
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, Object error) {
    return Center(
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(publicLobbiesProvider);
              },
              child: Text(
                'TRY AGAIN',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(Lobby lobby) {
    // TODO: Navigate to lobby detail screen with hero animation
    Navigator.of(context).pushNamed(
      '/squad-detail',
      arguments: lobby,
    );
  }
}
