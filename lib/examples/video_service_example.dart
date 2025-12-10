import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/video_service.dart';
import '../services/app_flow_manager.dart';
import '../chat/sqlite_helper.dart';
// import '../managers/stubs.dart'; // TODO: Restore if needed

/// Example: How to use VideoService in your SquadSync app
///
/// This file demonstrates the complete setup and usage of the VideoService
/// for video chat functionality with all features including:
/// - Camera controls (toggle, flip)
/// - Beauty filters
/// - Virtual backgrounds (blur or custom image)
/// - Audio/video muting
/// - Network quality monitoring

// 1. Create the VideoService provider
final videoServiceProvider = Provider<VideoService>((ref) {
  return VideoService(
    appFlowManager: AppFlowManager(FirebaseAnalytics.instance),
    sqliteHelper: SQLiteHelper(),
  );
});

// 2. Create VideoRoomNotifier provider
final videoRoomProvider = StateNotifierProvider.family<VideoRoomNotifier,
    AsyncValue<VideoRoomState>, Map<String, String>>((ref, params) {
  final videoService = ref.watch(videoServiceProvider);
  final roomId = params['roomId'] ?? '';
  final roomName = params['roomName'] ?? 'Video Room';

  return VideoRoomNotifier(
    roomId: roomId,
    roomName: roomName,
    videoService: videoService,
    appFlowManager: AppFlowManager(FirebaseAnalytics.instance),
    sqliteHelper: SQLiteHelper(),
  );
});

/// Example Video Chat Screen
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

class _VideoRoomScreenState extends ConsumerState<VideoRoomScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize video service when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndJoin();
    });
  }

  Future<void> _initializeAndJoin() async {
    final notifier = ref.read(videoRoomProvider({
      'roomId': widget.roomId,
      'roomName': widget.roomName,
    }).notifier);

    // Initialize the video service
    await notifier.initializeVideoService();

    // Join the room with video enabled
    await notifier.joinRoom(enableVideo: true);
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(videoRoomProvider({
      'roomId': widget.roomId,
      'roomName': widget.roomName,
    }));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        actions: [
          // Network quality indicator
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.network_check),
          ),
        ],
      ),
      body: roomState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeAndJoin,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (state) => _buildVideoRoom(state),
      ),
    );
  }

  Widget _buildVideoRoom(VideoRoomState state) {
    final notifier = ref.read(videoRoomProvider({
      'roomId': widget.roomId,
      'roomName': widget.roomName,
    }).notifier);

    return Column(
      children: [
        // Video grid
        Expanded(
          child: _buildVideoGrid(state, notifier),
        ),

        // Control panel
        _buildControlPanel(state, notifier),
      ],
    );
  }

  Widget _buildVideoGrid(VideoRoomState state, VideoRoomNotifier notifier) {
    final participants = state.participants;
    final gridCount = participants.length + 1; // +1 for local user

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCount > 4 ? 3 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: gridCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Local video view
          return _buildLocalVideoView(state, notifier);
        } else {
          // Remote video view
          final participant = participants[index - 1];
          return _buildRemoteVideoView(participant, notifier);
        }
      },
    );
  }

  Widget _buildLocalVideoView(
      VideoRoomState state, VideoRoomNotifier notifier) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Local video
            if (state.isVideoEnabled)
              notifier.getLocalVideoView()
            else
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off, size: 48, color: Colors.white),
                    SizedBox(height: 8),
                    Text('Camera Off', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),

            // Local user label
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),

            // Muted indicator
            if (state.isMuted)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.mic_off, color: Colors.red),
              ),

            // Virtual background indicator
            if (state.isVirtualBackgroundEnabled)
              const Positioned(
                top: 8,
                left: 8,
                child: Icon(Icons.blur_on, color: Colors.blue),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideoView(
      VideoParticipant participant, VideoRoomNotifier notifier) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Remote video
            if (participant.hasVideo)
              notifier.getRemoteVideoView(int.parse(participant.uid))
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      child: Text(
                        participant.displayName.isNotEmpty
                            ? participant.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Camera Off',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),

            // Participant label
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  participant.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),

            // Muted indicator
            if (participant.isMuted)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.mic_off, color: Colors.red),
              ),

            // Speaking indicator
            if (participant.isSpeaking)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel(VideoRoomState state, VideoRoomNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Toggle mute
                _buildControlButton(
                  icon: state.isMuted ? Icons.mic_off : Icons.mic,
                  label: state.isMuted ? 'Unmute' : 'Mute',
                  isActive: !state.isMuted,
                  onPressed: () => notifier.toggleMute(),
                ),

                // Toggle video
                _buildControlButton(
                  icon: state.isVideoEnabled
                      ? Icons.videocam
                      : Icons.videocam_off,
                  label: state.isVideoEnabled ? 'Stop Video' : 'Start Video',
                  isActive: state.isVideoEnabled,
                  onPressed: () => notifier.toggleVideo(),
                ),

                // Leave room
                _buildControlButton(
                  icon: Icons.call_end,
                  label: 'Leave',
                  isActive: false,
                  color: Colors.red,
                  onPressed: () async {
                    await notifier.leaveRoom();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Secondary controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Flip camera
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios),
                  onPressed: () => notifier.flipCamera(),
                  tooltip: 'Flip Camera',
                ),

                // Beauty filter
                IconButton(
                  icon: Icon(
                    Icons.face_retouching_natural,
                    color: state.isBeautyFilterEnabled ? Colors.blue : null,
                  ),
                  onPressed: () => notifier.toggleBeautyFilter(),
                  tooltip: 'Beauty Filter',
                ),

                // Virtual background
                IconButton(
                  icon: Icon(
                    Icons.blur_on,
                    color:
                        state.isVirtualBackgroundEnabled ? Colors.blue : null,
                  ),
                  onPressed: () => _showBackgroundOptions(notifier, state),
                  tooltip: 'Virtual Background',
                ),

                // More options
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showMoreOptions(context, notifier, state),
                  tooltip: 'More Options',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: color ??
              (isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest),
          child: Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _showBackgroundOptions(
      VideoRoomNotifier notifier, VideoRoomState state) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.blur_off),
              title: const Text('No Background'),
              onTap: () {
                notifier.disableVirtualBackground();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.blur_on),
              title: const Text('Blur Background'),
              onTap: () {
                notifier.enableVirtualBackground(blur: true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Custom Image'),
              onTap: () {
                // TODO: Implement image picker
                // final imagePath = await pickImage();
                // notifier.enableVirtualBackground(blur: false, imagePath: imagePath);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(
      BuildContext context, VideoRoomNotifier notifier, VideoRoomState state) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people),
              title: Text('Participants (${state.participants.length})'),
              onTap: () {
                Navigator.pop(context);
                _showParticipants(context, state);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Video Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to video settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Connection Info'),
              onTap: () {
                Navigator.pop(context);
                _showConnectionInfo(context, state);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showParticipants(BuildContext context, VideoRoomState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Participants'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.participants.length,
            itemBuilder: (context, index) {
              final participant = state.participants[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(participant.displayName[0].toUpperCase()),
                ),
                title: Text(participant.displayName),
                subtitle: Text(
                  participant.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: participant.isOnline ? Colors.green : Colors.grey,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (participant.isMuted)
                      const Icon(Icons.mic_off, size: 16, color: Colors.grey),
                    if (participant.hasVideo)
                      const Icon(Icons.videocam, size: 16, color: Colors.blue)
                    else
                      const Icon(Icons.videocam_off,
                          size: 16, color: Colors.grey),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showConnectionInfo(BuildContext context, VideoRoomState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room ID: ${state.roomId}'),
            Text('Room Name: ${state.roomName}'),
            Text(
                'Network: ${state.isNetworkAvailable ? "Connected" : "Disconnected"}'),
            Text('Reconnect Attempts: ${state.reconnectAttempts}'),
            Text('Host: ${state.isHost ? "Yes" : "No"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up - leave room when screen is disposed
    final notifier = ref.read(videoRoomProvider({
      'roomId': widget.roomId,
      'roomName': widget.roomName,
    }).notifier);
    notifier.leaveRoom();
    super.dispose();
  }
}

/// Example: Simple usage in your squad tab
/// 
/// Add a video call button to your squad screen:
/// 
/// ```dart
/// ElevatedButton(
///   onPressed: () {
///     Navigator.push(
///       context,
///       MaterialPageRoute(
///         builder: (context) => VideoRoomScreen(
///           roomId: 'squad_${squad.id}',
///           roomName: '${squad.name} Video',
///         ),
///       ),
///     );
///   },
///   child: const Text('Start Video Call'),
/// )
/// ```
