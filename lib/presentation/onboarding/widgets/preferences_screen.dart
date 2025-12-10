import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const PreferencesScreen({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen>
    with TickerProviderStateMixin {
  // Preference states
  bool _voiceReady = false;
  bool _micAlwaysOn = false;
  bool _lateNight = false;
  bool _isCompetitive = true; // true = Competitive, false = Chill

  // Animation controllers
  late AnimationController _glitchController;
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _glitchController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _triggerGlitch() {
    _glitchController.forward(from: 0);
  }

  void _handleComplete() async {
    HapticFeedback.heavyImpact();
    _triggerGlitch();

    // Save preferences to state
    // TODO: Save to UserNotifier when available
    final preferences = {
      'voiceReady': _voiceReady,
      'micAlwaysOn': _micAlwaysOn,
      'lateNight': _lateNight,
      'playStyle': _isCompetitive ? 'competitive' : 'chill',
    };

    debugPrint('Preferences saved: $preferences');

    // Wait for glitch animation to complete
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Title
              const SizedBox(height: 32),
              const Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.cyan,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Configure your squad experience',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.cyan.withOpacity(0.6),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 64),

              // 2x2 Grid of preference chips
              Expanded(
                child: _buildPreferencesGrid(),
              ),

              // Enter the Void button
              const SizedBox(height: 32),
              _buildEnterVoidButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            math.min(constraints.maxWidth, constraints.maxHeight) / 2 - 16;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Row 1
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPreferenceChip(
                  label: 'Voice Ready',
                  icon: Icons.mic,
                  selected: _voiceReady,
                  onTap: () {
                    setState(() => _voiceReady = !_voiceReady);
                    HapticFeedback.selectionClick();
                  },
                  size: size,
                ),
                const SizedBox(width: 16),
                _buildPreferenceChip(
                  label: 'Mic Always On',
                  icon: Icons.headset_mic,
                  selected: _micAlwaysOn,
                  onTap: () {
                    setState(() => _micAlwaysOn = !_micAlwaysOn);
                    HapticFeedback.selectionClick();
                  },
                  size: size,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Row 2
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPreferenceChip(
                  label: 'Late Night',
                  icon: Icons.nightlight_round,
                  selected: _lateNight,
                  onTap: () {
                    setState(() => _lateNight = !_lateNight);
                    HapticFeedback.selectionClick();
                  },
                  size: size,
                ),
                const SizedBox(width: 16),
                _buildPlayStyleSlider(size: size),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreferenceChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.cyan : Colors.cyan.withOpacity(0.3),
            width: 2,
          ),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.cyan.withOpacity(0.2),
                    Colors.purpleAccent.withOpacity(0.1),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: size * 0.35,
              color: selected ? Colors.cyan : Colors.grey.shade600,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayStyleSlider({required double size}) {
    return GestureDetector(
      onTap: () {
        setState(() => _isCompetitive = !_isCompetitive);
        HapticFeedback.selectionClick();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.cyan.withOpacity(0.5),
            width: 2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon based on selection
            Icon(
              _isCompetitive ? Icons.emoji_events : Icons.spa,
              size: size * 0.35,
              color: _isCompetitive ? Colors.orange : Colors.purple,
            ),
            const SizedBox(height: 12),

            // Slider track
            Container(
              width: size * 0.7,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black26,
              ),
              child: Stack(
                children: [
                  // Slider thumb
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: _isCompetitive ? 0 : size * 0.35,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: size * 0.35,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: _isCompetitive
                              ? [Colors.orange, Colors.deepOrange]
                              : [Colors.purple, Colors.deepPurple],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isCompetitive ? Colors.orange : Colors.purple)
                                    .withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Label
            Text(
              _isCompetitive ? 'COMPETITIVE' : 'CHILL',
              style: TextStyle(
                color: _isCompetitive ? Colors.orange : Colors.purple,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterVoidButton() {
    return GestureDetector(
      onTapDown: (_) {
        _hoverController.forward();
      },
      onTapUp: (_) {
        _hoverController.reverse();
        _handleComplete();
      },
      onTapCancel: () {
        _hoverController.reverse();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_glitchController, _hoverController]),
        builder: (context, child) {
          // Glitch effect parameters
          final glitchValue = _glitchController.value;
          final isGlitching = glitchValue > 0;
          final offsetX = isGlitching
              ? (math.sin(glitchValue * 50) * 5 * (1 - glitchValue))
              : 0.0;
          final offsetY = isGlitching
              ? (math.cos(glitchValue * 30) * 3 * (1 - glitchValue))
              : 0.0;

          return Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: Transform.scale(
              scale: 1.0 + (_hoverController.value * 0.05),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: isGlitching
                        ? [
                            Colors.cyan,
                            Colors.purpleAccent,
                            Colors.cyan,
                            Colors.purpleAccent,
                          ]
                        : [
                            Colors.cyan,
                            Colors.purpleAccent,
                          ],
                  ),
                  border: Border.all(
                    color: Colors.cyan,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    if (isGlitching)
                      BoxShadow(
                        color: Colors.purpleAccent.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Main text
                    Text(
                      'ENTER THE VOID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        shadows: isGlitching
                            ? [
                                Shadow(
                                  color: Colors.cyan,
                                  offset: Offset(-2 * glitchValue, 0),
                                  blurRadius: 5,
                                ),
                                Shadow(
                                  color: Colors.red,
                                  offset: Offset(2 * glitchValue, 0),
                                  blurRadius: 5,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    // Glitch overlay text
                    if (isGlitching)
                      Opacity(
                        opacity: 0.3 * glitchValue,
                        child: Transform.translate(
                          offset: Offset(
                            math.sin(glitchValue * 100) * 5,
                            0,
                          ),
                          child: Text(
                            'ENTER THE VOID',
                            style: TextStyle(
                              color:
                                  glitchValue > 0.5 ? Colors.cyan : Colors.red,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
