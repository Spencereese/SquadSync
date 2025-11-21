import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice_service.dart';
import '../services/agora_config.dart';
import '../providers.dart';

class VoiceRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;

  const VoiceRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  ConsumerState<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends ConsumerState<VoiceRoomScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the voice room
    // For prod, generate dynamic tokens server-side via backend route /agora/token
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Check if Agora config is available
        if (AgoraConfig.appId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voice chat config missing—contact support'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        await ref.read(voiceRoomProvider(widget.roomId).notifier).initialize();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to initialize voice room: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceRoomProvider(widget.roomId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ?? Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close,
              color: Theme.of(context).iconTheme.color ?? Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          voiceState.roomName,
          style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color ??
                  Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Room status
            if (voiceState.isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              )
            else if (voiceState.error != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: ${voiceState.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else if (!voiceState.isJoined)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Connecting to voice room...',
                  style: TextStyle(color: Colors.white),
                ),
              ),

            // Participants grid
            Expanded(
              child: _buildParticipantsGrid(voiceState.participants),
            ),

            // Control buttons
            _buildControlButtons(voiceState),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsGrid(List<VoiceParticipant> participants) {
    if (participants.isEmpty) {
      return Center(
        child: Text(
          'Waiting for participants...',
          style: TextStyle(
              color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.7) ??
                  Colors.white70,
              fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        return _buildParticipantCard(participants[index]);
      },
    );
  }

  Widget _buildParticipantCard(VoiceParticipant participant) {
    return Container(
      decoration: BoxDecoration(
        color: participant.isSpeaking
            ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
            : Theme.of(context).cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: participant.isSpeaking
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: participant.isHost
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            child: Text(
              participant.displayName.isNotEmpty
                  ? participant.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Name
          Text(
            participant.displayName,
            style: TextStyle(
              color:
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Status indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (participant.isHost)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Host',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (participant.isMuted) ...[
                if (participant.isHost) const SizedBox(width: 8),
                Icon(
                  Icons.mic_off,
                  color: Theme.of(context).colorScheme.error,
                  size: 16,
                ),
              ],
            ],
          ),

          // Speaking indicator
          if (participant.isSpeaking) ...[
            const SizedBox(height: 8),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.volume_up,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButtons(VoiceRoomState voiceState) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Join/Leave button
          ElevatedButton.icon(
            onPressed: voiceState.isJoined
                ? () => ref
                    .read(voiceRoomProvider(widget.roomId).notifier)
                    .leaveRoom()
                : () => ref
                    .read(voiceRoomProvider(widget.roomId).notifier)
                    .joinRoom(),
            icon: Icon(
              voiceState.isJoined ? Icons.call_end : Icons.call,
              color: voiceState.isJoined
                  ? Theme.of(context).colorScheme.onError
                  : Theme.of(context).colorScheme.onPrimary,
            ),
            label: Text(
              voiceState.isJoined ? 'Leave' : 'Join',
              style: TextStyle(
                color: voiceState.isJoined
                    ? Theme.of(context).colorScheme.onError
                    : Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: voiceState.isJoined
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),

          // Mute/Unmute button
          if (voiceState.isJoined)
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(voiceRoomProvider(widget.roomId).notifier)
                  .toggleMute(),
              icon: Icon(
                voiceState.isMuted ? Icons.mic_off : Icons.mic,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: Text(
                voiceState.isMuted ? 'Unmute' : 'Mute',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: voiceState.isMuted
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
