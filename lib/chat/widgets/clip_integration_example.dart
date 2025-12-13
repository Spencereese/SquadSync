import 'package:flutter/material.dart';
import '../models/message_data.dart' as models;
import '../../domain/entities/message.dart';
import 'clip_message_bubble.dart';

/// Example integration of ClipMessageBubble into message rendering
///
/// Add this to your MessageBubble or MessageContent widget where you handle different message types.

Widget buildMessageContent(
  BuildContext context,
  models.MessageData messageData,
  bool isMe,
  String chatGroupId,
  ChatType chatType,
  Color? gameColor,
) {
  switch (messageData.type) {
    case models.MessageType.text:
      return Text(messageData.text);

    case models.MessageType.image:
      // Your image widget
      return const SizedBox();

    case models.MessageType.video:
      // Your video widget
      return const SizedBox();

    case models.MessageType.audio:
      // Your audio widget
      return const SizedBox();

    case models.MessageType.poll:
      // Your poll widget
      return const SizedBox();

    case models.MessageType.clip:
      // ✨ NEW: Neon Void Clip Message Bubble
      return ClipMessageBubble(
        messageData: messageData,
        isMe: isMe,
        chatGroupId: chatGroupId,
        chatType: chatType,
        gameColor: gameColor, // Pass current game's neon color
      );

    case models.MessageType.system:
      // Your system message widget
      return const SizedBox();
  }
}

/// Example: How to get the game color from squad context
///
/// Use this in your chat screen to pass dynamic game colors to clips:
///
/// ```dart
/// Color? getGameColor(BuildContext context, WidgetRef ref) {
///   final squadState = ref.watch(ln.lobbyNotifierProvider);
///   final currentGame = squadState.value?.currentGame;
///
///   // Map game names to neon colors (or pull from game metadata)
///   switch (currentGame?.name) {
///     case 'Call of Duty':
///       return const Color(0xFF00FF00); // Green
///     case 'Fortnite':
///       return const Color(0xFFFF00FF); // Magenta
///     case 'Apex Legends':
///       return const Color(0xFFFF0000); // Red
///     case 'Warzone':
///       return const Color(0xFFFFFF00); // Yellow
///     default:
///       return const Color(0xFF00FFFF); // Cyan (default)
///   }
/// }
/// ```

/// Example: Full chat message widget with clip support
class ExampleChatMessage extends StatelessWidget {
  final models.MessageData messageData;
  final bool isMe;
  final String chatGroupId;
  final ChatType chatType;
  final List<models.MessageData>? allMessages; // For auto-play

  const ExampleChatMessage({
    super.key,
    required this.messageData,
    required this.isMe,
    required this.chatGroupId,
    required this.chatType,
    this.allMessages,
  });

  @override
  Widget build(BuildContext context) {
    // For clips, render the specialized clip bubble
    if (messageData.type == models.MessageType.clip) {
      // Get all clips from messages for auto-play
      final squadClips =
          allMessages?.where((m) => m.type == models.MessageType.clip).toList();

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ClipMessageBubble(
          messageData: messageData,
          isMe: isMe,
          chatGroupId: chatGroupId,
          chatType: chatType,
          gameColor: _getGameColor(), // Get from your game context
          squadClips: squadClips, // Enable auto-play next
        ),
      );
    }

    // For other message types, use your existing bubble
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        // Your existing message bubble design
        child: Text(messageData.text),
      ),
    );
  }

  Color _getGameColor() {
    // TODO: Get from LobbyNotifier or GameNotifier
    return const Color(0xFF00FFFF); // Default cyan
  }
}

/// Example: Sending a clip from chat screen
/// 
/// ```dart
/// Future<void> sendClip(String videoPath, WidgetRef ref) async {
///   try {
///     await ref.read(chatNotifierProvider.notifier).sendMessage(
///       chatGroupId: 'squad_123',
///       chatType: ChatType.squad,
///       content: 'Check out this clip!',
///       messageType: MessageType.clip,
///       clipFilePath: videoPath, // Path to video file
///       onUploadProgress: (progress) {
///         print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
///       },
///     );
///   } catch (e) {
///     print('Failed to send clip: $e');
///   }
/// }
/// ```

/// Example: Opening ClipPlayerScreen directly with auto-play
/// 
/// ```dart
/// void openClipPlayer(
///   BuildContext context,
///   MessageData selectedClip,
///   List<MessageData> allMessages,
/// ) {
///   // Filter to only clip messages for auto-play
///   final squadClips = allMessages
///       .where((m) => m.type == MessageType.clip)
///       .toList();
/// 
///   Navigator.push(
///     context,
///     MaterialPageRoute(
///       builder: (context) => ClipPlayerScreen(
///         clipData: selectedClip.clipData!,
///         messageData: selectedClip,
///         chatGroupId: 'squad_123',
///         chatType: ChatType.squad,
///         gameColor: Color(0xFF00FF00), // Game-specific neon
///         squadClips: squadClips, // Enable auto-play next
///       ),
///       fullscreenDialog: true,
///     ),
///   );
/// }
/// ```

/// Example: Handling deep links to clips
/// 
/// ```dart
/// void handleClipDeepLink(Uri uri) {
///   // URI format: codsquadapp://clip/{chatGroupId}/{messageId}
///   if (uri.pathSegments[0] == 'clip') {
///     final chatGroupId = uri.pathSegments[1];
///     final messageId = uri.pathSegments[2];
///     
///     // Fetch clip message from Firestore
///     FirebaseFirestore.instance
///         .collection('lobbies/$chatGroupId/chat')
///         .doc(messageId)
///         .get()
///         .then((doc) {
///       final messageData = MessageData.fromDocument(doc);
///       
///       Navigator.push(
///         context,
///         MaterialPageRoute(
///           builder: (context) => ClipPlayerScreen(
///             clipData: messageData.clipData!,
///             messageData: messageData,
///             chatGroupId: chatGroupId,
///             chatType: ChatType.squad,
///           ),
///           fullscreenDialog: true,
///         ),
///       );
///     });
///   }
/// }
/// ```
