import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';

/// Voice room screen with spatial audio visualization
///
/// Features:
/// - Floating glass orbs for participants in grid layout
/// - Dynamic orb scaling and neon ring pulsing based on voice volume
/// - Host crown indicator that floats above avatar
/// - Muted users shown dimmed with red slash
/// - Raise hand peacock feather animation
/// - Animated particle background with game-themed gradients
/// - Glass bottom control bar with glow effects
/// - Screen share preview in corner
/// - Agora RTC integration with spatial audio
class VoiceRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String squadName;
  final bool isHost;
  final Color? themeColor;

  const VoiceRoomScreen({
    super.key,
    required this.roomId,
    required this.squadName,
    this.isHost = false,
    this.themeColor,
  });

  @override
  ConsumerState<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends ConsumerState<VoiceRoomScreen>
    with TickerProviderStateMixin {
  // Voice state
  final Map<String, double> _userVolumes = {};
  final Set<String> _raisedHands = {};
  String? _screenShareUserId;

  // Local state
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isHandRaised = false;

  // Animation controllers
  late AnimationController _particleController;
  final Map<String, AnimationController> _orbPulseControllers = {};

  // Mock participants (replace with actual data from VoiceService)
  List<VoiceParticipant> _participants = [];

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _initializeVoiceRoom();
    _loadMockParticipants();
  }

  @override
  void dispose() {
    _particleController.dispose();
    for (final controller in _orbPulseControllers.values) {
      controller.dispose();
    }
    _leaveVoiceRoom();
    super.dispose();
  }

  Future<void> _initializeVoiceRoom() async {
    // TODO: Initialize VoiceService and join channel
    // final voiceService = ref.read(voiceServiceProvider);
    // await voiceService.joinChannel(widget.roomId);

    // Setup volume change listener
    // voiceService.onVolumeChanged = (userId, volume) {
    //   setState(() {
    //     _userVolumes[userId] = volume;
    //   });
    // };
  }

  Future<void> _leaveVoiceRoom() async {
    // TODO: Leave voice channel
    // final voiceService = ref.read(voiceServiceProvider);
    // await voiceService.leaveChannel();
  }

  void _loadMockParticipants() {
    // Mock data for demonstration
    setState(() {
      _participants = [
        VoiceParticipant(
          id: 'user1',
          name: 'CaptainGamer',
          avatarUrl: null,
          isHost: true,
          isMuted: false,
        ),
        VoiceParticipant(
          id: 'user2',
          name: 'SnipeKing',
          avatarUrl: null,
          isHost: false,
          isMuted: false,
        ),
        VoiceParticipant(
          id: 'user3',
          name: 'ProPlayer99',
          avatarUrl: null,
          isHost: false,
          isMuted: true,
        ),
        VoiceParticipant(
          id: 'user4',
          name: 'NinjaWarrior',
          avatarUrl: null,
          isHost: false,
          isMuted: false,
        ),
      ];

      // Initialize pulse controllers
      for (final participant in _participants) {
        _orbPulseControllers[participant.id] = AnimationController(
          duration: const Duration(milliseconds: 300),
          vsync: this,
        );
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    HapticFeedback.mediumImpact();
    // TODO: Update voice service
    // ref.read(voiceServiceProvider).toggleMute();
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    HapticFeedback.lightImpact();
    // TODO: Update voice service
    // ref.read(voiceServiceProvider).toggleSpeaker();
  }

  void _toggleHandRaise() {
    setState(() {
      _isHandRaised = !_isHandRaised;
      if (_isHandRaised) {
        _raisedHands.add('currentUser');
      } else {
        _raisedHands.remove('currentUser');
      }
    });
    HapticFeedback.heavyImpact();
    // TODO: Notify other participants
  }

  void _leaveRoom() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.themeColor ?? theme.colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(theme, accentColor),
      body: Stack(
        children: [
          // Animated background with particles
          _buildAnimatedBackground(accentColor),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Room info header
                _buildRoomHeader(theme, accentColor),

                // Participant orbs grid
                Expanded(
                  child: _buildParticipantGrid(theme, accentColor),
                ),

                // Raised hands queue bar
                if (_raisedHands.isNotEmpty)
                  _buildRaisedHandsBar(theme, accentColor),

                // Bottom control bar
                _buildControlBar(theme, accentColor),
              ],
            ),
          ),

          // Screen share preview (if active)
          if (_screenShareUserId != null)
            _buildScreenSharePreview(theme, accentColor),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, Color accentColor) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: _leaveRoom,
      ),
      title: Text(
        'VOICE ROOM',
        style: GoogleFonts.orbitron(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () {
            // Show room options
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedBackground(Color accentColor) {
    return Stack(
      children: [
        // Game-themed gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0B0E14),
                accentColor.withOpacity(0.1),
                const Color(0xFF14181F),
                accentColor.withOpacity(0.15),
                const Color(0xFF0B0E14),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        ),

        // Animated particles
        AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            return CustomPaint(
              painter: _ParticlePainter(
                progress: _particleController.value,
                color: accentColor,
              ),
              size: Size.infinite,
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoomHeader(ThemeData theme, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.group_rounded,
                  color: accentColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.squadName,
                        style: GoogleFonts.orbitron(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_participants.length} in room',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_rounded,
                        size: 16,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantGrid(ThemeData theme, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.9,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _participants.length,
        itemBuilder: (context, index) {
          final participant = _participants[index];
          return _buildParticipantOrb(theme, accentColor, participant);
        },
      ),
    );
  }

  Widget _buildParticipantOrb(
    ThemeData theme,
    Color accentColor,
    VoiceParticipant participant,
  ) {
    final volume = _userVolumes[participant.id] ?? 0.0;
    final isSpeaking = volume > 0.1;
    final isHandRaised = _raisedHands.contains(participant.id);

    // Trigger pulse animation when speaking
    if (isSpeaking &&
        !(_orbPulseControllers[participant.id]?.isAnimating ?? false)) {
      _orbPulseControllers[participant.id]?.repeat(reverse: true);
    } else if (!isSpeaking) {
      _orbPulseControllers[participant.id]?.stop();
      _orbPulseControllers[participant.id]?.reset();
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Raised hand peacock feather
        if (isHandRaised)
          Positioned(
            top: -30,
            child: Text(
              '🦚',
              style: const TextStyle(fontSize: 48),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .moveY(
                  begin: 0,
                  end: -10,
                  duration: 1500.ms,
                  curve: Curves.easeInOut,
                )
                .rotate(
                  begin: -0.1,
                  end: 0.1,
                  duration: 1500.ms,
                  curve: Curves.easeInOut,
                ),
          ),

        // Host crown
        if (participant.isHost)
          Positioned(
            top: -20,
            child: Text(
              '👑',
              style: const TextStyle(fontSize: 32),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .moveY(
                  begin: 0,
                  end: -5,
                  duration: 2000.ms,
                  curve: Curves.easeInOut,
                )
                .shimmer(
                  duration: 2000.ms,
                  color: Colors.amber.withOpacity(0.5),
                ),
          ),

        // Main orb
        AnimatedBuilder(
          animation: _orbPulseControllers[participant.id]!,
          builder: (context, child) {
            final scale = isSpeaking
                ? 1.0 + (_orbPulseControllers[participant.id]!.value * 0.3)
                : 1.0;

            return Transform.scale(
              scale: scale,
              child: _buildOrbContent(theme, accentColor, participant, volume),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOrbContent(
    ThemeData theme,
    Color accentColor,
    VoiceParticipant participant,
    double volume,
  ) {
    final isSpeaking = volume > 0.1;
    final orbColor = participant.isMuted ? Colors.grey : accentColor;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Neon ring (pulsing when speaking)
        if (isSpeaking)
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: orbColor,
                width: 3,
              ),
              boxShadow: orbColor.neonGlow(
                blur: 20 + (volume * 30),
                opacity: 0.6 + (volume * 0.4),
              ),
            ),
          )
              .animate(
                onPlay: (controller) => controller.repeat(),
              )
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.15, 1.15),
                duration: 500.ms,
                curve: Curves.easeInOut,
              )
              .fadeOut(
                begin: 1.0,
                duration: 500.ms,
              ),

        // Waveform ring
        if (isSpeaking)
          SizedBox(
            width: 130,
            height: 130,
            child: CustomPaint(
              painter: _WaveformRingPainter(
                color: orbColor,
                volume: volume,
              ),
            ),
          ),

        // Glass orb
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.white.withOpacity(participant.isMuted ? 0.05 : 0.12),
                border: Border.all(
                  color: orbColor.withOpacity(0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Avatar or initial
                  _buildAvatar(participant, orbColor),

                  // Mute slash overlay
                  if (participant.isMuted)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: const Icon(
                        Icons.mic_off_rounded,
                        size: 40,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Name label below
        Positioned(
          bottom: -30,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: orbColor.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Text(
              participant.name,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(VoiceParticipant participant, Color accentColor) {
    if (participant.avatarUrl != null) {
      return ClipOval(
        child: Image.network(
          participant.avatarUrl!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildAvatarFallback(participant, accentColor),
        ),
      );
    }

    return _buildAvatarFallback(participant, accentColor);
  }

  Widget _buildAvatarFallback(VoiceParticipant participant, Color accentColor) {
    final initial =
        participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?';

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor,
            accentColor.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.orbitron(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRaisedHandsBar(ThemeData theme, Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '✋',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_raisedHands.length} raised hand${_raisedHands.length > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Lower all hands
                    setState(() {
                      _raisedHands.clear();
                      _isHandRaised = false;
                    });
                  },
                  child: Text(
                    'CLEAR',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildControlBar(ThemeData theme, Color accentColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentColor.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: accentColor.neonGlow(blur: 20, opacity: 0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: _isMuted ? 'Unmute' : 'Mute',
                  color: _isMuted ? Colors.red : accentColor,
                  isActive: !_isMuted,
                  onPressed: _toggleMute,
                ),
                _buildControlButton(
                  icon: _isSpeakerOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  label: 'Speaker',
                  color: accentColor,
                  isActive: _isSpeakerOn,
                  onPressed: _toggleSpeaker,
                ),
                _buildControlButton(
                  icon: Icons.back_hand_rounded,
                  label: 'Raise',
                  color: Colors.amber,
                  isActive: _isHandRaised,
                  onPressed: _toggleHandRaise,
                ),
                _buildControlButton(
                  icon: Icons.call_end_rounded,
                  label: 'Leave',
                  color: Colors.red,
                  isActive: false,
                  onPressed: _leaveRoom,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: isActive ? color.neonGlow(blur: 15, opacity: 0.4) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? color : Colors.white70,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? color : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    ).animate(target: isActive ? 1 : 0).scaleXY(
          begin: 1.0,
          end: 1.05,
          duration: 200.ms,
        );
  }

  Widget _buildScreenSharePreview(ThemeData theme, Color accentColor) {
    return Positioned(
      top: 100,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 140,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: accentColor.neonGlow(blur: 15, opacity: 0.4),
            ),
            child: Stack(
              children: [
                // Screen share content would go here
                Center(
                  child: Icon(
                    Icons.screen_share_rounded,
                    size: 40,
                    color: accentColor.withOpacity(0.6),
                  ),
                ),

                // Close button
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _screenShareUserId = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideX(begin: 0.3, duration: 400.ms, curve: Curves.easeOut),
    );
  }
}

/// Voice participant model
class VoiceParticipant {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isHost;
  final bool isMuted;

  VoiceParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isHost = false,
    this.isMuted = false,
  });
}

/// Custom painter for animated particles in background
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ParticlePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistency

    for (int i = 0; i < 30; i++) {
      final x =
          (random.nextDouble() * size.width + (progress * 50)) % size.width;
      final y =
          (random.nextDouble() * size.height + (progress * 30)) % size.height;
      final radius = 2 + random.nextDouble() * 4;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint..color = color.withOpacity(0.1 + random.nextDouble() * 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Custom painter for waveform ring around speaking user
class _WaveformRingPainter extends CustomPainter {
  final Color color;
  final double volume;

  _WaveformRingPainter({
    required this.color,
    required this.volume,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final segmentCount = 20;
    final segmentAngle = (2 * math.pi) / segmentCount;

    for (int i = 0; i < segmentCount; i++) {
      final angle = i * segmentAngle - math.pi / 2;
      final nextAngle = (i + 1) * segmentAngle - math.pi / 2;

      // Vary height based on volume
      final height = 5 + (volume * 15 * math.sin(i * 0.5));

      final innerRadius = radius - height;

      final startOuter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final endOuter = Offset(
        center.dx + radius * math.cos(nextAngle),
        center.dy + radius * math.sin(nextAngle),
      );

      final startInner = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );

      final endInner = Offset(
        center.dx + innerRadius * math.cos(nextAngle),
        center.dy + innerRadius * math.sin(nextAngle),
      );

      // Draw segment
      final path = Path()
        ..moveTo(startOuter.dx, startOuter.dy)
        ..lineTo(startInner.dx, startInner.dy)
        ..lineTo(endInner.dx, endInner.dy)
        ..lineTo(endOuter.dx, endOuter.dy)
        ..close();

      canvas.drawPath(path, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_WaveformRingPainter oldDelegate) {
    return oldDelegate.volume != volume;
  }
}
