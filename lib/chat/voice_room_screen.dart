import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/voice_service.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceRoomProvider(widget.roomId).notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceRoomProvider(widget.roomId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          voiceState.roomName,
          style: const TextStyle(color: Colors.white),
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
                  style: const TextStyle(color: Colors.red),
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
      return const Center(
        child: Text(
          'Waiting for participants...',
          style: TextStyle(color: Colors.white70, fontSize: 16),
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
            ? Colors.cyanAccent.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              participant.isSpeaking ? Colors.cyanAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor:
                participant.isHost ? Colors.cyanAccent : Colors.grey[700],
            child: Text(
              participant.displayName.isNotEmpty
                  ? participant.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Name
          Text(
            participant.displayName,
            style: const TextStyle(
              color: Colors.white,
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
                    color: Colors.cyanAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Host',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (participant.isMuted) ...[
                if (participant.isHost) const SizedBox(width: 8),
                const Icon(
                  Icons.mic_off,
                  color: Colors.red,
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
              decoration: const BoxDecoration(
                color: Colors.cyanAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volume_up,
                color: Colors.black,
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
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              color: voiceState.isJoined ? Colors.white : Colors.black,
            ),
            label: Text(
              voiceState.isJoined ? 'Leave' : 'Join',
              style: TextStyle(
                color: voiceState.isJoined ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  voiceState.isJoined ? Colors.red : Colors.cyanAccent,
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
                color: Colors.black,
              ),
              label: Text(
                voiceState.isMuted ? 'Unmute' : 'Mute',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    voiceState.isMuted ? Colors.red : Colors.cyanAccent,
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
