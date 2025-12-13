import 'package:flutter/material.dart';
import '../../../screens/voice_room_screen.dart';
import '../../../screens/video_room_screen.dart';
import 'chat_info_widgets.dart';

/// Actions section with big circular buttons for squad actions
///
/// Features:
/// - Voice chat navigation
/// - Video chat navigation (with beta badge)
/// - Search functionality
/// - Glassmorphic button design
class ChatInfoActionsSection extends StatelessWidget {
  final String squadId;
  final String squadName;
  final Color neonColor;

  const ChatInfoActionsSection({
    super.key,
    required this.squadId,
    required this.squadName,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ChatInfoBigActionButton(
            icon: Icons.headset,
            label: 'Voice Chat',
            neonColor: neonColor,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VoiceRoomScreen(
                    roomId: squadId,
                    squadName: squadName,
                  ),
                ),
              );
            },
          ),
          ChatInfoBigActionButton(
            icon: Icons.video_call,
            label: 'Video Chat',
            neonColor: neonColor,
            badge: 'Beta',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoRoomScreen(
                    roomId: squadId,
                    roomName: squadName,
                  ),
                ),
              );
            },
          ),
          ChatInfoBigActionButton(
            icon: Icons.search,
            label: 'Search',
            neonColor: neonColor,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search feature coming soon!'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
