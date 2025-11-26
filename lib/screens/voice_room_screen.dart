import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../app_theme.dart';

class VoiceRoomScreen extends StatelessWidget {
  final String roomId;
  final String roomName;

  const VoiceRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  Widget build(BuildContext context) {
    return _VoiceRoomScreenContent(roomId: roomId, roomName: roomName);
  }
}

class _VoiceRoomScreenContent extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;

  const _VoiceRoomScreenContent({
    required this.roomId,
    required this.roomName,
  });

  @override
  ConsumerState<_VoiceRoomScreenContent> createState() =>
      _VoiceRoomScreenContentState();
}

class _VoiceRoomScreenContentState
    extends ConsumerState<_VoiceRoomScreenContent>
    with TickerProviderStateMixin {
  late AnimationController _joinAnimationController;
  late Animation<double> _joinAnimation;
  late AnimationController _participantAnimationController;
  late Animation<double> _participantAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _joinAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _joinAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _joinAnimationController, curve: Curves.elasticOut),
    );

    _participantAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _participantAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _participantAnimationController, curve: Curves.easeOut),
    );

    // Initialize voice service when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVoiceService();
    });
  }

  @override
  void dispose() {
    _joinAnimationController.dispose();
    _participantAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeVoiceService() async {
    try {
      await ref
          .read(voiceRoomProvider(widget.roomId).notifier)
          .initializeVoiceService();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to initialize voice service: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _initializeVoiceService,
          ),
        ),
      );
    }
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isDenied && mounted) {
      _showPermissionDialog();
    } else if (status.isPermanentlyDenied && mounted) {
      _showPermissionSettingsDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'Voice chat requires microphone access to work. Please grant permission to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _requestMicrophonePermission();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Microphone permission is permanently denied. Please enable it in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voiceRoomAsync = ref.watch(voiceRoomProvider(widget.roomId));

    // Handle errors with snackbar
    voiceRoomAsync.whenOrNull(
      error: (error, stack) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showErrorSnackBar('Voice error: $error');
        });
      },
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.roomName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showRoomSettings(context),
            tooltip: 'Room Settings',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF0D0D0D),
            ],
          ),
        ),
        child: SafeArea(
          child: voiceRoomAsync.when(
            data: (voiceRoomState) => _buildVoiceRoomContent(voiceRoomState),
            loading: () => _buildLoadingContent(),
            error: (error, stack) => _buildErrorFallbackContent(error),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Initializing voice room...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorFallbackContent(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.voice_over_off_outlined,
              size: 80,
              color: AppTheme.errorColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            const Text(
              'Voice Unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check permissions and network connection',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializeVoiceService,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceRoomContent(voiceRoomState) {
    final participants = voiceRoomState.participants ?? [];
    final isJoined = voiceRoomState.isJoined ?? false;
    final isMuted = voiceRoomState.isMuted ?? false;
    final isHost = voiceRoomState.isHost ?? false;
    final isLoading = voiceRoomState.isLoading ?? false;
    final isNetworkAvailable = voiceRoomState.isNetworkAvailable ?? true;

    // Trigger participant animation when participants change
    if (participants.isNotEmpty) {
      _participantAnimationController.forward();
    }

    return Column(
      children: [
        // Network status indicator
        if (!isNetworkAvailable)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Network connection lost',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),

        // Participants grid
        Expanded(
          child: participants.isEmpty
              ? _buildEmptyState()
              : _buildParticipantsGrid(participants, isHost),
        ),

        // Control panel
        _buildControlPanel(isJoined, isMuted, isHost, isLoading),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Waiting for participants...',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Share the room link to invite others',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsGrid(List participants, bool isCurrentUserHost) {
    return AnimatedBuilder(
      animation: _participantAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _participantAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(_participantAnimation),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                return _buildParticipantCard(participant, isCurrentUserHost);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticipantCard(participant, bool isCurrentUserHost) {
    final uid = participant.uid ?? '';
    final userStateAsync = ref.watch(userNotifierProvider);
    final displayName = userStateAsync.maybeWhen(
      data: (state) =>
          ref.read(userNotifierProvider.notifier).getDisplayNameForUid(uid) ??
          'Unknown',
      orElse: () => 'Unknown',
    );
    final isMuted = participant.isMuted ?? false;
    final isSpeaking = participant.isSpeaking ?? false;
    final isHost = participant.isHost ?? false;
    final isOnline = participant.isOnline ?? true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpeaking
              ? AppTheme.primaryColor
              : Colors.white.withValues(alpha: 0.1),
          width: isSpeaking ? 3 : 1,
        ),
        color: Colors.white.withValues(alpha: 0.05),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with speaking animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSpeaking ? 72 : 64,
              height: isSpeaking ? 72 : 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSpeaking
                      ? AppTheme.primaryColor
                      : Colors.white.withValues(alpha: 0.3),
                  width: isSpeaking ? 3 : 2,
                ),
              ),
              child: CircleAvatar(
                backgroundColor: isOnline
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Name and status
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Host indicator
            if (isHost) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'Host',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Status indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Online status
                Icon(
                  isOnline ? Icons.circle : Icons.circle_outlined,
                  color: isOnline ? Colors.green : Colors.grey,
                  size: 12,
                ),
                const SizedBox(width: 8),
                // Mute status
                Icon(
                  isMuted ? Icons.mic_off : Icons.mic,
                  color: isMuted ? AppTheme.errorColor : Colors.green,
                  size: 12,
                ),
                if (isSpeaking) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.volume_up,
                    color: AppTheme.primaryColor,
                    size: 12,
                  ),
                ],
              ],
            ),

            // Host controls for individual participants
            if (isCurrentUserHost &&
                uid != FirebaseAuth.instance.currentUser?.uid) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.mic_off,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await ref
                          .read(voiceRoomProvider(widget.roomId).notifier)
                          .muteParticipant(uid, !isMuted);
                    },
                    tooltip: isMuted ? 'Unmute' : 'Mute',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.person_remove,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await ref
                          .read(voiceRoomProvider(widget.roomId).notifier)
                          .kickParticipant(uid);
                    },
                    tooltip: 'Kick',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel(
      bool isJoined, bool isMuted, bool isHost, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Join/Leave button
              AnimatedBuilder(
                animation: _joinAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isJoined ? _joinAnimation.value : 1.0,
                    child: ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              if (isJoined) {
                                await ref
                                    .read(voiceRoomProvider(widget.roomId)
                                        .notifier)
                                    .leaveRoom();
                              } else {
                                await _requestMicrophonePermission();
                                await ref
                                    .read(voiceRoomProvider(widget.roomId)
                                        .notifier)
                                    .joinRoom();
                                _joinAnimationController.forward(from: 0.0);
                              }
                            },
                      icon: Icon(isJoined ? Icons.call_end : Icons.call),
                      label: Text(isJoined ? 'Leave' : 'Join Voice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isJoined
                            ? AppTheme.errorColor
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Mute/Unmute button
              if (isJoined)
                ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(voiceRoomProvider(widget.roomId).notifier)
                        .toggleMute();
                  },
                  icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
                  label: Text(isMuted ? 'Unmute' : 'Mute'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMuted ? Colors.grey : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

              // Host controls
              if (isHost && isJoined)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    HapticFeedback.lightImpact();
                    switch (value) {
                      case 'mute_all':
                        // TODO: Implement mute all
                        break;
                      case 'lock_room':
                        // TODO: Implement room locking
                        break;
                      case 'manage_participants':
                        // TODO: Show participant management dialog
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'mute_all',
                      child: Text('Mute All'),
                    ),
                    const PopupMenuItem(
                      value: 'lock_room',
                      child: Text('Lock Room'),
                    ),
                    const PopupMenuItem(
                      value: 'manage_participants',
                      child: Text('Manage Participants'),
                    ),
                  ],
                  child: ElevatedButton.icon(
                    onPressed: null, // Handled by popup
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Host'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Status text
          if (isJoined) ...[
            const SizedBox(height: 16),
            Text(
              isMuted ? 'You are muted' : 'You are unmuted',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRoomSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Room Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.lock_outline, color: Colors.white70),
              title: const Text('Room Password',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Not set',
                  style: TextStyle(color: Colors.white70)),
              onTap: () {
                // TODO: Implement room password setting
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: Icon(Icons.people_outline, color: Colors.white70),
              title: const Text('Max Participants',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Unlimited',
                  style: TextStyle(color: Colors.white70)),
              onTap: () {
                // TODO: Implement max participants setting
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: Icon(Icons.mic_none, color: Colors.white70),
              title: const Text('Mute on Join',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Disabled',
                  style: TextStyle(color: Colors.white70)),
              trailing: Switch(
                value: false,
                onChanged: (value) {
                  // TODO: Implement mute on join setting
                },
                activeThumbColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
