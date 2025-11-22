import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../squad_state.dart';
import '../../services/ai_service.dart';
import '../chat_state.dart';
import '../chat_service.dart';
import '../message_bubble.dart';
import '../models/message_data.dart';
import '../models/message_group_data.dart';
import '../widgets/message_group.dart';
import '../chat_settings_menu.dart';
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

  // Swipe state for timestamp reveal
  final ValueNotifier<double> swipeOffset = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isRevealingTimestamps = ValueNotifier<bool>(false);

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

  // Animation for swipe back
  void _animateSwipeBack() {
    const int steps = 10;
    const Duration stepDuration = Duration(milliseconds: 16); // ~60fps
    final double startOffset = swipeOffset.value;
    int currentStep = 0;

    Timer.periodic(stepDuration, (timer) {
      currentStep++;
      final progress = currentStep / steps;
      // Spring-like easing: overshoot then settle
      final easedProgress = 1 - math.pow(1 - progress, 3); // Cubic ease out
      final newOffset = startOffset * (1 - easedProgress);

      swipeOffset.value = newOffset;

      if (currentStep >= steps) {
        swipeOffset.value = 0.0;
        timer.cancel();
      }
    });
  }

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

  /// Format timestamp for display (always show time only for swipe reveal)
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
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
    required VoidCallback onViewMediaGallery,
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
                    onViewMediaGallery: onViewMediaGallery,
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
  Widget buildActiveSquadHeader(BuildContext context, {String? chatGroupId}) {
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
            // Navigate directly to spots lobby for this game
            Navigator.pushNamed(context, '/squad', arguments: {
              'gameName': gameName,
              'game': currentGame,
              'chatGroupId': chatGroupId,
            });
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

        return StatefulBuilder(
          builder: (context, setState) {
            return ValueListenableBuilder<double>(
              valueListenable: swipeOffset,
              builder: (context, offset, child) {
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    // Allow tap events to pass through to parent for keyboard dismissal
                  },
                  onHorizontalDragUpdate: (details) {
                    // Only update if drag is mostly horizontal to avoid interfering with vertical scroll
                    if (details.delta.dx.abs() > details.delta.dy.abs()) {
                      // Dismiss keyboard on swipe
                      FocusScope.of(context).unfocus();
                      swipeOffset.value += details.delta.dx;
                      swipeOffset.value = swipeOffset.value.clamp(-40.0, 0.0);
                    }
                  },
                  onHorizontalDragEnd: (details) {
                    // Animate back to 0 with spring effect
                    _animateSwipeBack();
                  },
                  child: Stack(
                    children: [
                      // Main messages list
                      ListView.builder(
                        controller: scrollController.scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
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
                          final messageGroupIndex =
                              scrollController.isLoadingMore
                                  ? index - 1
                                  : index;
                          final messageGroup =
                              _processedMessages[messageGroupIndex]
                                  as MessageGroupData;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Stack(
                              children: [
                                Transform.translate(
                                  offset: Offset(offset, 0),
                                  child: MessageGroup(
                                    parentMessage: messageGroup.parentMessage,
                                    replies: messageGroup.replies,
                                    isMe:
                                        messageGroup.parentMessage.senderUid ==
                                            _auth.currentUser?.uid,
                                    showSender:
                                        true, // Will be determined per message in MessageGroup
                                    showAvatar:
                                        true, // Will be determined per message in MessageGroup
                                    showTimestamp: messageGroup.parentMessage
                                        .shouldShowTimestamp, // Show timestamp based on time gap logic
                                    showReadIndicator:
                                        false, // TODO: Implement per-message read indicators
                                    onTap: onMessageTap,
                                    onLongPress:
                                        () {}, // Handled by individual MessageBubbles
                                    sendingStatus: {}, // TODO: Pass appropriate sending status
                                    chatGroupId: chatGroupId,
                                    chatType: chatType,
                                    chatService: _chatService,
                                  ).animate().fadeIn(duration: 300.ms),
                                ),
                                if (offset < -2)
                                  Positioned(
                                    right: 0,
                                    top: messageGroup
                                            .parentMessage.shouldShowTimestamp
                                        ? 40
                                        : 0,
                                    height: 60,
                                    child: Transform.translate(
                                      offset: Offset(
                                          (50 + offset * 1.25).clamp(0, 50), 0),
                                      child: Container(
                                        width: 50,
                                        alignment: Alignment.center,
                                        child: Text(
                                          _formatTimestamp(messageGroup
                                              .parentMessage.timestamp),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Build the reply preview widget
  Widget buildReplyPreview(BuildContext context, ChatState chatState,
      SquadState squadState, ChatType chatType) {
    final replyMessage = chatState.replyToMessage!;

    // Determine if the reply message is from the current user
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMe = replyMessage['senderUid'] == currentUser?.uid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Stack(
        children: [
          // Full-size tap detector for dismissing by tapping outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                chatState.clearReplyToMessage();
              },
              behavior: HitTestBehavior.translucent,
            ),
          ),
          // The actual message bubble
          MessageBubble(
            message: replyMessage,
            isMe: isMe,
            showSender: !isMe, // Show sender name if not from current user
            showAvatar: !isMe, // Show avatar if not from current user
            showTimestamp: true,
            showReadIndicator: false,
            onTap: () {}, // No action needed for reply preview
            onLongPress: () {}, // No action needed for reply preview
            sendingStatus: chatState.sendingStatus,
            chatGroupId: null, // Not needed for preview
            chatType: chatType,
            chatService: _chatService,
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
    // Convert messages to MessageData objects
    final messageDataList = messages.where((message) {
      final data = message is DocumentSnapshot
          ? message.data() as Map<String, dynamic>?
          : message as Map<String, dynamic>;
      return data != null;
    }).map((message) {
      final data = message is DocumentSnapshot
          ? message.data() as Map<String, dynamic>
          : message as Map<String, dynamic>;
      return MessageData.fromMap(data);
    }).toList();

    // Sort messages by timestamp (oldest first) for processing
    messageDataList.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Mark messages that should show timestamps based on time gaps
    const int timeGapThresholdMinutes =
        30; // Show timestamp if gap > 30 minutes
    DateTime? lastTimestamp;

    for (final message in messageDataList) {
      if (lastTimestamp == null) {
        // First message always shows timestamp
        message.shouldShowTimestamp = true;
      } else {
        final timeDifference = message.timestamp.difference(lastTimestamp);
        if (timeDifference.inMinutes >= timeGapThresholdMinutes) {
          message.shouldShowTimestamp = true;
        } else {
          message.shouldShowTimestamp = false;
        }
      }
      lastTimestamp = message.timestamp;
    }

    // Create message groups (simplified - no thread grouping)
    final List<MessageGroupData> messageGroups = [];

    for (final message in messageDataList) {
      // Each message is its own group with no replies
      messageGroups.add(MessageGroupData(
        parentMessage: message,
        replies: [],
      ));
    }

    // Sort messages by timestamp (most recent first for reverse list)
    messageGroups.sort((a, b) =>
        b.parentMessage.timestamp.compareTo(a.parentMessage.timestamp));

    _processedMessages = messageGroups;
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
    required VoidCallback onViewMediaGallery,
  }) {
    ChatSettingsMenu.showChatOptions(
      context: context,
      onSearchMessages: () {
        // TODO: Implement search messages
      },
      onChangeChatName: onChangeChatName,
      onChangeChatImage: onChangeChatImage,
      onClearChat: onClearChat,
      onQuickReactionPicker: onQuickReactionPicker,
      onToggleNotifications: onToggleNotifications,
      isMuted: false, // TODO: Get actual mute status
      onViewGroupInfo: onViewGroupInfo,
      onReportBug: onReportBug,
      onLeaveGroup: onLeaveGroup,
      onViewMediaGallery: onViewMediaGallery,
    );
  }
}
