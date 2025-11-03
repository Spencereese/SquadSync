import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../squad_state.dart';
import '../../services/ai_service.dart';
import '../chat_state.dart';
import '../chat_service.dart';
import '../message_bubble.dart';
import 'chat_scroll_controller.dart';

/// Service responsible for coordinating UI state and building complex UI components
/// for the chat screen. This extracts the complex build logic from ChatScreen.
class ChatUIManager {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // UI state
  String _searchQuery = '';
  String _chatName = 'Squad Chat';
  String? _chatImageUrl;
  bool _isMuted = false;

  // Caches
  final Map<String, String> _userDisplayNameCache = {};
  List<dynamic> _processedMessages = [];
  final Map<String, List<String>> _lastReadByCache = {};
  bool _needsMessageProcessing = true;

  // Getters for UI state
  String get searchQuery => _searchQuery;
  String get chatName => _chatName;
  String? get chatImageUrl => _chatImageUrl;
  bool get isMuted => _isMuted;
  Map<String, String> get userDisplayNameCache => _userDisplayNameCache;
  List<dynamic> get processedMessages => _processedMessages;
  Map<String, List<String>> get lastReadByCache => _lastReadByCache;
  bool get needsMessageProcessing => _needsMessageProcessing;

  // Setters for UI state
  set searchQuery(String value) => _searchQuery = value;
  set chatName(String value) => _chatName = value;
  set chatImageUrl(String? value) => _chatImageUrl = value;
  set isMuted(bool value) => _isMuted = value;
  set processedMessages(List<dynamic> value) => _processedMessages = value;
  set needsMessageProcessing(bool value) => _needsMessageProcessing = value;

  /// Initialize UI state
  void initialize({
    required String initialChatName,
    String? initialChatImageUrl,
    bool initialIsMuted = false,
  }) {
    _chatName = initialChatName;
    _chatImageUrl = initialChatImageUrl;
    _isMuted = initialIsMuted;
  }

  /// Build the chat header with settings menu and online count
  Widget buildChatHeader({
    required BuildContext context,
    required String? chatGroupId,
    required SquadState squadState,
    required VoidCallback onBackPressed,
    required VoidCallback onToggleNotifications,
    required VoidCallback onViewGroupInfo,
    required VoidCallback onReportBug,
    required VoidCallback onLeaveGroup,
    required Future<void> Function() onChangeChatName,
    required Future<void> Function() onChangeChatImage,
    required Future<void> Function() onClearChat,
    required VoidCallback onQuickReactionPicker,
    required VoidCallback onInviteMembers,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 300),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chat settings menu
              Expanded(
                child: GestureDetector(
                  onTap: () => _showChatOptionsMenu(
                    context: context,
                    chatGroupId: chatGroupId,
                    squadState: squadState,
                    onChangeChatName: onChangeChatName,
                    onChangeChatImage: onChangeChatImage,
                    onClearChat: onClearChat,
                    onQuickReactionPicker: onQuickReactionPicker,
                    onToggleNotifications: onToggleNotifications,
                    onViewGroupInfo: onViewGroupInfo,
                    onReportBug: onReportBug,
                    onLeaveGroup: onLeaveGroup,
                    onInviteMembers: onInviteMembers,
                  ),
                  child: Semantics(
                    label: 'Chat options',
                    child: Row(
                      children: [
                        // Back button for chat groups
                        if (chatGroupId != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.cyanAccent,
                                size: 24,
                              ),
                              onPressed: onBackPressed,
                              tooltip: 'Back to groups',
                            ),
                          ),
                        // Chat image/avatar
                        if (_chatImageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(_chatImageUrl!),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: CircleAvatar(
                              radius: 20,
                              child:
                                  Icon(Icons.group, color: Colors.cyanAccent),
                            ),
                          ),
                        // Chat name
                        Expanded(
                          child: Text(
                            _chatName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Squad button/counter
              Consumer<SquadState>(
                builder: (context, squadState, _) {
                  // Count how many squad members are currently in squad spots
                  int inSquadCount = 0;
                  final squadMembers = squadState.squadMembers;

                  // Check all games for squad spots occupied by squad members
                  for (final gameSpots in squadState.gameSquadSpots.values) {
                    for (final spot in gameSpots) {
                      if (spot != null && squadMembers.contains(spot)) {
                        inSquadCount++;
                      }
                    }
                  }

                  final showCounter = inSquadCount > 0;

                  return GestureDetector(
                    onTap: () {
                      // Navigate to squad tab
                      Navigator.pushNamed(context, '/squad');
                    },
                    child: Semantics(
                      label: showCounter
                          ? '$inSquadCount squad members in game spots, tap to view squad'
                          : 'View squad, tap to see squad spots',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: showCounter
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Text(
                              showCounter ? 'In Squad: $inSquadCount' : 'Squad',
                              style: TextStyle(
                                fontSize: 14,
                                color: showCounter
                                    ? Colors.greenAccent
                                    : Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              showCounter
                                  ? Icons.group
                                  : Icons.keyboard_arrow_down,
                              color: showCounter
                                  ? Colors.greenAccent.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.7),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the active squad header card
  Widget buildActiveSquadHeader(BuildContext context) {
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        final currentGame = squadState.currentGame;
        if (currentGame == null) {
          return const SizedBox.shrink();
        }

        final gameName = currentGame['name'] ?? 'Unknown Game';
        final maxSpots = currentGame['maxSpots'] ?? 4;
        final spots = squadState.gameSquadSpots[gameName] ?? [];
        final claimed = spots.where((spot) => spot != null).length;

        // Only show if there are claimed spots
        if (claimed == 0) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            // Navigate to squad tab for this game
            Navigator.pushNamed(context, '/squad', arguments: gameName);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.cyanAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your Active Squad: $gameName - $claimed/$maxSpots spots',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build the messages list with StreamBuilder
  Widget buildMessagesList({
    required BuildContext context,
    required String? chatGroupId,
    required ChatType chatType,
    required ChatScrollController scrollController,
    required SquadState squadState,
    required ChatState chatState,
    required VoidCallback onMessageLongPress,
    required VoidCallback onMessageTap,
    required String? Function(dynamic) getSender,
    required int? Function(dynamic) getTimestampMs,
    required String Function(String) cleanText,
    required Future<void> Function(String) markAsDelivered,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getChatMessages(context,
          chatGroupId: chatGroupId, chatType: chatType),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading chat'));
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Process messages
        List<dynamic> allMessages = [];
        if (snapshot.hasData) {
          // Cache messages from Firestore to SQLite
          _chatService.cacheMessagesFromSnapshot(snapshot.data!, chatGroupId);
          allMessages.addAll(snapshot.data!.docs);
        }

        // Process messages if needed
        if (_needsMessageProcessing ||
            allMessages.length != _processedMessages.length) {
          _processMessages(allMessages, cleanText);
        }

        if (_processedMessages.isEmpty) {
          return const Center(
            child:
                Text('No messages yet', style: TextStyle(color: Colors.white)),
          );
        }

        return ListView.builder(
          controller: scrollController.scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          itemCount: _processedMessages.length +
              (scrollController.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at the top
            if (index == 0 && scrollController.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ),
              );
            }

            // Adjust index for loading indicator
            final messageIndex =
                scrollController.isLoadingMore ? index - 1 : index;
            var message = _processedMessages[messageIndex];
            final data = message is DocumentSnapshot
                ? message.data() as Map<String, dynamic>?
                : message as Map<String, dynamic>;
            if (data == null) return const SizedBox.shrink();

            // Clean text
            final cleanedData = Map<String, dynamic>.from(data);
            if (cleanedData['content'] != null) {
              cleanedData['content'] = cleanText(cleanedData['content']);
            }
            if (cleanedData['text'] != null) {
              cleanedData['text'] = cleanText(cleanedData['text']);
            }

            // Mark as delivered
            bool isMe = cleanedData['senderUid'] == _auth.currentUser?.uid;
            if (!isMe && !(cleanedData['delivered'] ?? false)) {
              if (message is DocumentSnapshot) {
                markAsDelivered(message.id);
              }
            }

            // Determine display properties
            String? currentSender = getSender(message);
            String? nextSender = index < _processedMessages.length - 1
                ? getSender(_processedMessages[index + 1])
                : null;
            String? prevSender =
                index > 0 ? getSender(_processedMessages[index - 1]) : null;

            bool showSender = !isMe &&
                (index == _processedMessages.length - 1 ||
                    currentSender != nextSender);
            bool showAvatar =
                !isMe && (index == 0 || currentSender != prevSender);

            int? currentTimestamp = getTimestampMs(message);
            int? prevTimestamp = index > 0
                ? getTimestampMs(_processedMessages[index - 1])
                : null;
            bool showTimestamp = index > 0 &&
                currentTimestamp != null &&
                prevTimestamp != null &&
                DateTime.fromMillisecondsSinceEpoch(prevTimestamp)
                        .difference(DateTime.fromMillisecondsSinceEpoch(
                            currentTimestamp))
                        .inMinutes >
                    30;

            bool showReadIndicator = !isMe &&
                _lastReadByCache[cleanedData['senderUid'] ?? '']
                        ?.contains(_auth.currentUser!.uid) ==
                    true;

            final senderUid = cleanedData['senderUid'] as String?;
            final displayName = senderUid != null
                ? _userDisplayNameCache[senderUid] ??
                    squadState.getDisplayNameForUid(senderUid)
                : 'Unknown';

            cleanedData['sender'] = displayName;

            return GestureDetector(
              onLongPress: onMessageLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: MessageBubble(
                  message: cleanedData,
                  isMe: isMe,
                  showSender: showSender,
                  showAvatar: showAvatar,
                  showTimestamp: showTimestamp,
                  showReadIndicator: showReadIndicator,
                  onTap: onMessageTap,
                  onLongPress: () {}, // Handled by parent GestureDetector
                  sendingStatus: chatState.sendingStatus,
                  chatGroupId: chatGroupId,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Build the reply preview widget
  Widget buildReplyPreview(BuildContext context, ChatState chatState) {
    final replyMessage = chatState.replyToMessage!;
    final sender = replyMessage['sender'] ?? 'Unknown';
    final text = replyMessage['text'] ?? replyMessage['content'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $sender',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[200],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text.length > 100 ? '${text.substring(0, 100)}...' : text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: Colors.white70),
            onPressed: () {
              chatState.clearReplyToMessage();
              // Haptic feedback would be handled by caller
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Build the jump to bottom floating button
  Widget buildJumpToBottomButton({
    required double bottomPadding,
    required VoidCallback onJumpToBottom,
  }) {
    return Positioned(
      bottom: bottomPadding + 80,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: onJumpToBottom,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_downward,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  /// Process messages for display
  void _processMessages(
      List<dynamic> messages, String Function(String) cleanText) {
    _processedMessages = messages.where((message) {
      final data = message is DocumentSnapshot
          ? message.data() as Map<String, dynamic>?
          : message as Map<String, dynamic>;
      return data != null;
    }).toList();

    _needsMessageProcessing = false;
  }

  /// Show chat options menu
  void _showChatOptionsMenu({
    required BuildContext context,
    required String? chatGroupId,
    required SquadState squadState,
    required Future<void> Function() onChangeChatName,
    required Future<void> Function() onChangeChatImage,
    required Future<void> Function() onClearChat,
    required VoidCallback onQuickReactionPicker,
    required VoidCallback onToggleNotifications,
    required VoidCallback onViewGroupInfo,
    required VoidCallback onReportBug,
    required VoidCallback onLeaveGroup,
    required VoidCallback onInviteMembers,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Group name header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      if (_chatImageUrl != null)
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(_chatImageUrl!),
                        )
                      else
                        const CircleAvatar(
                          radius: 24,
                          child: Icon(Icons.group, color: Colors.cyanAccent),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _chatName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${squadState.statuses.length} members',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),

                // Menu options
                _buildMenuOption(
                  icon: Icons.info_outline,
                  title: 'Group Info',
                  onTap: () {
                    Navigator.pop(context);
                    onViewGroupInfo();
                  },
                ),

                if (chatGroupId != null) ...[
                  _buildMenuOption(
                    icon: Icons.person_add,
                    title: 'Invite Members',
                    onTap: () {
                      Navigator.pop(context);
                      onInviteMembers();
                    },
                  ),
                  _buildMenuOption(
                    icon: Icons.edit,
                    title: 'Change Group Name',
                    onTap: () async {
                      Navigator.pop(context);
                      await onChangeChatName();
                    },
                  ),
                  _buildMenuOption(
                    icon: Icons.photo_camera,
                    title: 'Change Group Photo',
                    onTap: () async {
                      Navigator.pop(context);
                      await onChangeChatImage();
                    },
                  ),
                  _buildMenuOption(
                    icon: Icons.clear_all,
                    title: 'Clear Chat',
                    onTap: () async {
                      Navigator.pop(context);
                      await onClearChat();
                    },
                  ),
                  _buildMenuOption(
                    icon: Icons.logout,
                    title: 'Leave Group',
                    textColor: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      onLeaveGroup();
                    },
                  ),
                ],

                const Divider(color: Colors.white24),
                const SizedBox(height: 10),

                _buildMenuOption(
                  icon:
                      _isMuted ? Icons.notifications_off : Icons.notifications,
                  title:
                      _isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                  onTap: () {
                    Navigator.pop(context);
                    onToggleNotifications();
                  },
                ),

                _buildMenuOption(
                  icon: Icons.bug_report,
                  title: 'Report Bug',
                  onTap: () {
                    Navigator.pop(context);
                    onReportBug();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? Colors.cyanAccent,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
