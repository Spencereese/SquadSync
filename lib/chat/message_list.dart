import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'chat_service.dart';
import 'message_bubble.dart';
import 'chat_state.dart';
import '../squad_state.dart';
import 'chat_modals.dart';

class MessageList extends StatefulWidget {
  final ScrollController scrollController;
  final int messageLimit;
  final ChatService chatService;
  final VoidCallback onScrollToBottom;

  const MessageList({
    super.key,
    required this.scrollController,
    required this.messageLimit,
    required this.chatService,
    required this.onScrollToBottom,
  });

  @override
  MessageListState createState() => MessageListState();
}

class MessageListState extends State<MessageList> {
  String? _scrollToMessageId;

  @override
  void initState() {
    super.initState();
    Provider.of<ChatState>(context, listen: false)
        .addListener(_handleScrollToMessage);
  }

  @override
  void dispose() {
    Provider.of<ChatState>(context, listen: false)
        .removeListener(_handleScrollToMessage);
    super.dispose();
  }

  void _handleScrollToMessage() {
    final chatState = Provider.of<ChatState>(context, listen: false);
    if (chatState.replyToMessage != null) {
      setState(() {
        _scrollToMessageId = chatState.replyToMessage!.id;
      });
    }
  }

  void _scrollToMessage(
      String messageId, List<QueryDocumentSnapshot> messages) {
    int index = messages.indexWhere((doc) => doc.id == messageId);
    if (index != -1 && widget.scrollController.hasClients) {
      widget.scrollController.animateTo(
        index * 60.0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.chatService
          .getChatMessages()
          .map((event) => event..docs.take(widget.messageLimit)),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading chat'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return const Center(child: Text('No messages yet'));
        }

        if (_scrollToMessageId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToMessage(_scrollToMessageId!, messages);
            setState(() {
              _scrollToMessageId = null;
            });
          });
        }

        Map<String, List<String>> lastReadBy = {};
        for (var doc in messages) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['read'] == true) {
            String sender = data['sender'];
            String uid = FirebaseAuth.instance.currentUser!.uid;
            if (!lastReadBy.containsKey(sender)) {
              lastReadBy[sender] = [];
            }
            if (!lastReadBy[sender]!.contains(uid)) {
              lastReadBy[sender]!.add(uid);
            }
          }
        }

        return ListView.builder(
          controller: widget.scrollController,
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            var message = messages[index];
            String? myName =
                Provider.of<SquadState>(context, listen: false).displayName;
            bool isMe = message['sender'] ==
                (FirebaseAuth.instance.currentUser!.displayName ??
                    myName ??
                    'User');
            if (!isMe && !(message['delivered'] ?? false)) {
              widget.chatService.markAsDelivered(message.id);
            }
            bool showSender = !isMe &&
                (index == messages.length - 1 ||
                    messages[index + 1]['sender'] != message['sender']);
            bool showAvatar = !isMe &&
                (index == 0 ||
                    messages[index - 1]['sender'] != message['sender']);
            bool showTimestamp = index > 0 &&
                messages[index - 1]['timestamp'] != null &&
                message['timestamp'] != null &&
                (messages[index - 1]['timestamp'] as Timestamp)
                        .toDate()
                        .difference(
                            (message['timestamp'] as Timestamp).toDate())
                        .inMinutes >
                    30;
            bool showReadIndicator = !isMe &&
                lastReadBy[message['sender']]
                        ?.contains(FirebaseAuth.instance.currentUser!.uid) ==
                    true;

            return MessageBubble(
              message: message,
              isMe: isMe,
              showSender: showSender,
              showAvatar: showAvatar,
              showTimestamp: showTimestamp,
              showReadIndicator: showReadIndicator,
              onTap: () => ChatModals.showMessageDetails(context, message),
              onLongPress: () => ChatModals.showMessageOptions(
                context,
                message.id,
                (message.data() as Map<String, dynamic>)['text'] ?? '',
                isMe,
                widget.chatService,
                () async {
                  await Clipboard.setData(ClipboardData(
                      text: (message.data() as Map<String, dynamic>)['text'] ??
                          ''));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')));
                },
                () => debugPrint('Forward not implemented'),
              ),
              sendingStatus:
                  Provider.of<ChatState>(context, listen: false).sendingStatus,
              chatService: widget.chatService, // Pass ChatService here
            );
          },
        );
      },
    );
  }
}
