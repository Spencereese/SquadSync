import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/video_service.dart';
import '../services/app_flow_manager.dart';
import '../chat/sqlite_helper.dart';
import '../core/app_theme.dart';

/// NEON VOID styled video room screen with glassmorphic UI
/// Features adaptive grid, floating PiP, and neon speaking indicators
class VideoRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;

  const VideoRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  ConsumerState<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends ConsumerState<VideoRoomScreen>
    with TickerProviderStateMixin {
  late AnimationController _speakingAnimationController;
  late AnimationController _pulseAnimationController;
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;
  Offset _pipPosition = const Offset(20, 100);

  // Video room provider
  late final StateNotifierProvider<VideoRoomNotifier,
      AsyncValue<VideoRoomState>> _videoRoomProvider;

  @override
  void initState() {
    super.initState();

    // Create provider for this specific room
    _videoRoomProvider =
        StateNotifierProvider<VideoRoomNotifier, AsyncValue<VideoRoomState>>(
            (ref) {
      final videoService = VideoService(
        appFlowManager: AppFlowManager(FirebaseAnalytics.instance),
        sqliteHelper: SQLiteHelper(),
      );

      return VideoRoomNotifier(
        roomId: widget.roomId,
        roomName: widget.roomName,
        videoService: videoService,
        appFlowManager: AppFlowManager(FirebaseAnalytics.instance),
        sqliteHelper: SQLiteHelper(),
      );
    });

    // Speaking indicator animations
    _speakingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Initialize and join room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndJoin();
    });

    // Start call duration timer
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _callDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _initializeAndJoin() async {
    final notifier = ref.read(_videoRoomProvider.notifier);

    // Initialize video service
    await notifier.initializeVideoService();

    // Enable virtual background blur by default
    await notifier.enableVirtualBackground(blur: true);

    // Join room with video enabled
    await notifier.joinRoom(enableVideo: true);
  }

  @override
  void dispose() {
    _speakingAnimationController.dispose();
    _pulseAnimationController.dispose();
    _durationTimer?.cancel();

    // Leave room
    final notifier = ref.read(_videoRoomProvider.notifier);
    notifier.leaveRoom();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomState = ref.watch(_videoRoomProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: roomState.when(
        loading: () => _buildLoadingView(theme),
        error: (error, stack) => _buildErrorView(theme, error.toString()),
        data: (state) => _buildVideoRoom(theme, state),
      ),
    );
  }

  Widget _buildLoadingView(ThemeData theme) {
    return Center(
      child: GlassmorphicContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Joining ${widget.roomName}...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preparing camera and microphone',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme, String error) {
    return Center(
      child: GlassmorphicContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Failed',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _initializeAndJoin,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Exit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoRoom(ThemeData theme, VideoRoomState state) {
    final notifier = ref.read(_videoRoomProvider.notifier);
    final totalParticipants =
        state.participants.length + 1; // +1 for local user
    final useFloatingPip = totalParticipants > 4;

    return Stack(
      children: [
        // Main video grid
        Column(
          children: [
            // Top bar
            _buildTopBar(theme, state, totalParticipants),

            // Video grid
            Expanded(
              child: _buildAdaptiveVideoGrid(
                  theme, state, notifier, useFloatingPip),
            ),

            // Bottom control bar
            _buildControlBar(theme, state, notifier),
          ],
        ),

        // Floating PiP for local video (when >4 users)
        if (useFloatingPip) _buildFloatingPip(theme, state, notifier),
      ],
    );
  }

  Widget _buildTopBar(
      ThemeData theme, VideoRoomState state, int totalParticipants) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Room name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.roomName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$totalParticipants participant${totalParticipants != 1 ? 's' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Call duration timer
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(_callDuration),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [const FontFeature.tabularFigures()],
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
      ),
    );
  }

  Widget _buildAdaptiveVideoGrid(
    ThemeData theme,
    VideoRoomState state,
    VideoRoomNotifier notifier,
    bool useFloatingPip,
  ) {
    final participants = state.participants;
    final displayParticipants =
        useFloatingPip ? participants : [...participants];
    final gridCount =
        useFloatingPip ? participants.length : participants.length + 1;

    // Adaptive grid based on participant count
    final crossAxisCount = _getGridCrossAxisCount(gridCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: gridCount,
        itemBuilder: (context, index) {
          if (!useFloatingPip && index == 0) {
            // Local user in grid
            return _buildLocalVideoTile(theme, state, notifier, false);
          } else {
            // Remote participant
            final participantIndex = useFloatingPip ? index : index - 1;
            final participant = displayParticipants[participantIndex];
            return _buildRemoteVideoTile(theme, participant, notifier);
          }
        },
      ),
    );
  }

  int _getGridCrossAxisCount(int participantCount) {
    if (participantCount <= 1) return 1;
    if (participantCount <= 4) return 2;
    return 3; // 3x3 grid for 5-9 participants
  }

  Widget _buildLocalVideoTile(
    ThemeData theme,
    VideoRoomState state,
    VideoRoomNotifier notifier,
    bool isFloating,
  ) {
    return AnimatedBuilder(
      animation: _pulseAnimationController,
      builder: (context, child) {
        final glowIntensity =
            state.isMuted ? 0.0 : _pulseAnimationController.value * 0.3;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isFloating ? 12 : 20),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.6 + glowIntensity),
              width: 2,
            ),
            boxShadow: theme.colorScheme.primary.neonGlow(
              blur: 20 + (glowIntensity * 20),
              opacity: 0.4 + glowIntensity,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isFloating ? 12 : 20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video or placeholder
                if (state.isVideoEnabled)
                  notifier.getLocalVideoView()
                else
                  _buildCameraOffPlaceholder(theme, 'You', true),

                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),

                // Local user label
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'You (Host)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.8),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (state.isMuted)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.mic_off,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),

                // Speaking indicator (waveform)
                if (!state.isMuted)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildWaveformIndicator(theme),
                  ),

                // Virtual background indicator
                if (state.isVirtualBackgroundEnabled)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.blur_on,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemoteVideoTile(
    ThemeData theme,
    VideoParticipant participant,
    VideoRoomNotifier notifier,
  ) {
    return AnimatedBuilder(
      animation: _pulseAnimationController,
      builder: (context, child) {
        final glowIntensity = participant.isSpeaking
            ? _pulseAnimationController.value * 0.4
            : 0.0;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: participant.isSpeaking
                  ? theme.colorScheme.primary.withOpacity(0.8 + glowIntensity)
                  : Colors.white.withOpacity(0.2),
              width: participant.isSpeaking ? 2.5 : 1.5,
            ),
            boxShadow: participant.isSpeaking
                ? theme.colorScheme.primary.neonGlow(
                    blur: 25 + (glowIntensity * 25),
                    opacity: 0.5 + glowIntensity,
                  )
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video or placeholder
                if (participant.hasVideo)
                  notifier.getRemoteVideoView(int.parse(participant.uid))
                else
                  _buildCameraOffPlaceholder(
                      theme, participant.displayName, false),

                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),

                // Participant info
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          participant.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.8),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (participant.isMuted)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.mic_off,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),

                // Speaking indicator ring
                if (participant.isSpeaking)
                  Positioned.fill(
                    child: _buildNeonPulseRing(theme),
                  ),

                // Waveform when speaking
                if (participant.isSpeaking)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildWaveformIndicator(theme),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraOffPlaceholder(
      ThemeData theme, String name, bool isLocal) {
    return Container(
      color: const Color(0xFF1A1F2E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.2),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Camera Off',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeonPulseRing(ThemeData theme) {
    return AnimatedBuilder(
      animation: _pulseAnimationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary
                  .withOpacity(0.6 * (1 - _pulseAnimationController.value)),
              width: 3,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaveformIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (index) => AnimatedBuilder(
            animation: _pulseAnimationController,
            builder: (context, child) {
              final delay = index * 0.2;
              final value = ((_pulseAnimationController.value + delay) % 1.0);
              final height = 4 + (value * 12);

              return Container(
                width: 2,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: theme.colorScheme.primary.neonGlow(
                    blur: 4,
                    opacity: 0.6,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingPip(
    ThemeData theme,
    VideoRoomState state,
    VideoRoomNotifier notifier,
  ) {
    return Positioned(
      left: _pipPosition.dx,
      top: _pipPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pipPosition = Offset(
              (_pipPosition.dx + details.delta.dx)
                  .clamp(0, MediaQuery.of(context).size.width - 120),
              (_pipPosition.dy + details.delta.dy)
                  .clamp(0, MediaQuery.of(context).size.height - 160),
            );
          });
        },
        child: Container(
          width: 120,
          height: 160,
          child: _buildLocalVideoTile(theme, state, notifier, true),
        ),
      ),
    );
  }

  Widget _buildControlBar(
    ThemeData theme,
    VideoRoomState state,
    VideoRoomNotifier notifier,
  ) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute/Unmute
                  _buildControlButton(
                    theme: theme,
                    icon: state.isMuted ? Icons.mic_off : Icons.mic,
                    label: state.isMuted ? 'Unmute' : 'Mute',
                    isActive: !state.isMuted,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      notifier.toggleMute();
                    },
                  ),

                  // Toggle Camera
                  _buildControlButton(
                    theme: theme,
                    icon: state.isVideoEnabled
                        ? Icons.videocam
                        : Icons.videocam_off,
                    label: state.isVideoEnabled ? 'Stop' : 'Start',
                    isActive: state.isVideoEnabled,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      notifier.toggleVideo();
                    },
                  ),

                  // Flip Camera
                  _buildControlButton(
                    theme: theme,
                    icon: Icons.flip_camera_ios,
                    label: 'Flip',
                    isActive: false,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      notifier.flipCamera();
                    },
                  ),

                  // Beauty/Virtual BG Toggle
                  _buildControlButton(
                    theme: theme,
                    icon: state.isVirtualBackgroundEnabled
                        ? Icons.blur_on
                        : Icons.blur_off,
                    label: 'Effects',
                    isActive: state.isVirtualBackgroundEnabled ||
                        state.isBeautyFilterEnabled,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showEffectsMenu(context, theme, state, notifier);
                    },
                  ),

                  // Leave Call
                  _buildControlButton(
                    theme: theme,
                    icon: Icons.call_end,
                    label: 'Leave',
                    isActive: false,
                    isDestructive: true,
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await _showLeaveConfirmation(context, theme, notifier);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? Colors.red
        : isActive
            ? theme.colorScheme.primary
            : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDestructive
                  ? Colors.red.withOpacity(0.2)
                  : isActive
                      ? theme.colorScheme.primary.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
              border: Border.all(
                color: color.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: isActive ? color.neonGlow(blur: 15, opacity: 0.4) : [],
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _showEffectsMenu(
    BuildContext context,
    ThemeData theme,
    VideoRoomState state,
    VideoRoomNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF14181F).withOpacity(0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Video Effects',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildEffectTile(
                    theme: theme,
                    icon: Icons.blur_on,
                    title: 'Virtual Background Blur',
                    isActive: state.isVirtualBackgroundEnabled,
                    onTap: () {
                      if (state.isVirtualBackgroundEnabled) {
                        notifier.disableVirtualBackground();
                      } else {
                        notifier.enableVirtualBackground(blur: true);
                      }
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildEffectTile(
                    theme: theme,
                    icon: Icons.face_retouching_natural,
                    title: 'Beauty Filter',
                    isActive: state.isBeautyFilterEnabled,
                    onTap: () {
                      notifier.toggleBeautyFilter();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEffectTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary.withOpacity(0.6)
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: isActive
              ? theme.colorScheme.primary.neonGlow(blur: 12, opacity: 0.3)
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isActive ? theme.colorScheme.primary : Colors.white60,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isActive)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLeaveConfirmation(
    BuildContext context,
    ThemeData theme,
    VideoRoomNotifier notifier,
  ) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF14181F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          title: Text(
            'Leave Video Call?',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
            ),
          ),
          content: Text(
            'You will be disconnected from ${widget.roomName}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.2),
                side: BorderSide(color: Colors.red, width: 1.5),
              ),
              child: const Text('Leave'),
            ),
          ],
        ),
      ),
    );

    if (shouldLeave == true && mounted) {
      await notifier.leaveRoom();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
