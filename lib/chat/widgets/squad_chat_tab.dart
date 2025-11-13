import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../squad_state.dart';
import '../chat_screen.dart';
import '../chat_state.dart';
import '../../services/ai_service.dart';

class SquadChatTab extends StatelessWidget {
  const SquadChatTab({super.key});

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  Widget _buildDMCard(BuildContext context) {
    return Consumer<ChatState>(
      builder: (context, chatState, child) {
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[800],
            child: const Icon(
              Icons.message,
              color: Colors.cyanAccent,
              size: 24,
            ),
          ),
          title: const Text(
            'Direct Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Private conversations',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          trailing: chatState.dmUnreadCount > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.cyanAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    chatState.dmUnreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          onTap: () => chatState.setDMView(true),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final SquadState squadState = Provider.of<SquadState>(context);

    // Get user's squads and display them as chat groups
    final userSquadIds = squadState.userSquadIds;

    if (userSquadIds.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'No squads available. Join or create a squad to start chatting!',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: userSquadIds.length + 1, // +1 for DM card
        separatorBuilder: (context, index) => const Divider(
          color: Colors.grey,
          height: 0.5,
          indent: 72,
          thickness: 0.5,
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            // DM card
            return _buildDMCard(context);
          }

          final squadIndex = index - 1;
          final squadId = userSquadIds[squadIndex];

          // Skip invalid squad IDs
          if (squadId.isEmpty) {
            return const SizedBox.shrink();
          }

          // Get squad data
          return FutureBuilder<DocumentSnapshot>(
            future: firestore.collection('squads').doc(squadId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  ),
                  title:
                      Text('Loading...', style: TextStyle(color: Colors.white)),
                );
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  !snapshot.data!.exists) {
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.error, color: Colors.red),
                  ),
                  title: Text(
                    'Error loading squad',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    squadId,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                );
              }

              final squadData = snapshot.data!.data() as Map<String, dynamic>;
              final squadName = squadData['name'] ?? 'Unnamed Squad';
              final memberCount = squadData['memberCount'] ?? 0;
              final imageUrl = squadData['imageUrl'];

              // Get last message from the squad's messages collection
              return StreamBuilder<QuerySnapshot>(
                key: ValueKey('squad_messages_$squadId'),
                stream: firestore
                    .collection('squads')
                    .doc(squadId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, messageSnapshot) {
                  String lastMessage = '';
                  DateTime? lastMessageTime;

                  if (messageSnapshot.hasData &&
                      messageSnapshot.data!.docs.isNotEmpty) {
                    final messageDoc = messageSnapshot.data!.docs.first;
                    final messageData =
                        messageDoc.data() as Map<String, dynamic>;
                    lastMessage = messageData['text'] ?? '';
                    final timestamp = messageData['timestamp'];
                    if (timestamp is Timestamp) {
                      lastMessageTime = timestamp.toDate();
                    }
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[800],
                      backgroundImage:
                          imageUrl != null ? NetworkImage(imageUrl) : null,
                      child: imageUrl == null
                          ? const Icon(
                              Icons.group,
                              color: Colors.cyanAccent,
                              size: 24,
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            squadName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastMessageTime != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              _formatTime(lastMessageTime),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        lastMessage.isNotEmpty
                            ? lastMessage
                            : '$memberCount members',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onTap: () {
                      // Navigate to chat screen for this squad
                      debugPrint(
                          'DEBUG SquadChatTab: Tapping on squad $squadId');
                      debugPrint(
                          'DEBUG SquadChatTab: userSquadIds = ${squadState.userSquadIds}');
                      debugPrint(
                          'DEBUG SquadChatTab: userSquads keys = ${squadState.userSquads.keys}');
                      // squadState.selectSquad(squadId); // Remove this - we'll pass squadId directly
                      debugPrint(
                          'DEBUG SquadChatTab: After selectSquad, selectedSquadId = ${squadState.selectedSquadId}');
                      if (squadId.isNotEmpty &&
                          squadState.userSquadIds.contains(squadId)) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatType: ChatType.dm,
                              chatGroupId: squadId,
                            ),
                          ),
                        );
                      } else {
                        debugPrint(
                            'DEBUG SquadChatTab: squadId is invalid or not in list, not navigating');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Unable to open squad chat')),
                        );
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
