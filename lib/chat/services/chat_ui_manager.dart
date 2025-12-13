import 'dart:async';
import 'dart:math' as math;
import '../../services/auth_service_supabase.dart';
import '../../services/message_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as r;
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_state.dart' as cn_state;
import '../models/message_data.dart' as md;
import '../message_bubble.dart';
import '../models/message_data.dart';
import '../models/message_group_data.dart';
import '../widgets/message_group.dart';
import '../chat_settings_menu.dart';
import 'chat_scroll_controller.dart';
import 'chat_message_search_delegate.dart';

/// Service responsible for coordinating UI state and building complex UI components
/// for the chat screen. This extracts the complex build logic from ChatScreen.
class ChatUIManager {
  final MessageService _chatService = MessageService();

  // UI state
  String _searchQuery = '';
  String _chatName = 'Lobby Chat';
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
    // Convert to local time if needed
    final localTime = timestamp.isUtc ? timestamp.toLocal() : timestamp;
    return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  /// Build the chat header with settings menu and online count
  Widget buildChatHeader({
    required BuildContext context,
    required String? chatGroupId,
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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
                              icon: Icon(
                                Icons.arrow_back,
                                color: Theme.of(context).colorScheme.primary,
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
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: CircleAvatar(
                              radius: 20,
                              child: Icon(Icons.group,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        // Chat name
                        Expanded(
                          child: Text(
                            _chatName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Lobby button/counter
              r.Consumer(
                builder: (context, ref, _) {
                  final squadAsync = ref.watch(ln.lobbyNotifierProvider);
                  final squadState = squadAsync.value;
                  if (squadState == null) return const SizedBox.shrink();

                  // Count how many lobby members are currently in lobby spots
                  int inLobbyCount = 0;
                  final squadMembers = squadState.lobbyMemberUids;

                  // Check all games for lobby spots occupied by lobby members
                  for (final gameSpots in squadState.gameLobbySpots.values) {
                    for (final spot in gameSpots) {
                      if (spot != null && squadMembers.contains(spot)) {
                        inLobbyCount++;
                      }
                    }
                  }

                  final showCounter = inLobbyCount > 0;

                  return GestureDetector(
                    onTap: () {
                      // Navigate to squad tab
                      Navigator.pushNamed(context, '/squad');
                    },
                    child: Semantics(
                      label: showCounter
                          ? '$inLobbyCount lobby members in game spots, tap to view squad'
                          : 'View squad, tap to see squad spots',
                      child: Builder(
                        builder: (context) {
                          final theme = Theme.of(context);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: showCounter
                                  ? theme.colorScheme.tertiary.withOpacity(0.2)
                                  : theme.colorScheme.surface.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  showCounter
                                      ? 'In Lobby: $inLobbyCount'
                                      : 'Lobby',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: showCounter
                                        ? theme.colorScheme.tertiary
                                        : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  showCounter
                                      ? Icons.group
                                      : Icons.keyboard_arrow_down,
                                  color: showCounter
                                      ? theme.colorScheme.tertiary
                                          .withOpacity(0.7)
                                      : theme.colorScheme.onSurface
                                          .withOpacity(0.7),
                                  size: 16,
                                ),
                              ],
                            ),
                          );
                        },
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
  Widget buildActiveLobbyHeader(BuildContext context, {String? chatGroupId}) {
    return r.Consumer(
      builder: (context, ref, child) {
        final squadAsync = ref.watch(ln.lobbyNotifierProvider);
        final squadState = squadAsync.value;
        if (squadState == null) return const SizedBox.shrink();

        final currentGame = squadState.currentGame;
        if (currentGame == null) {
          return const SizedBox.shrink();
        }

        final gameName = currentGame['name'] ?? 'Unknown Game';
        final maxSpots = currentGame['maxSpots'] ?? 4;
        final spots = squadState.gameLobbySpots[gameName] ?? [];
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
                    'Your Active Lobby: $gameName - $claimed/$maxSpots spots',
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

  /// Build the messages list with provided messages
  Widget buildMessagesList({
    required r.WidgetRef ref,
    required String? chatGroupId,
    required ChatType chatType,
    required ChatScrollController scrollController,
    required List<Message> messages,
    cn_state.ChatState? chatState,
    required VoidCallback onMessageLongPress,
    required VoidCallback onMessageTap,
    required String? Function(dynamic) getSender,
    required int? Function(dynamic) getTimestampMs,
    required String Function(String) cleanText,
    Future<void> Function(String)?
        markAsDelivered, // Made optional for Supabase migration
  }) {
    // Process messages if needed
    if (_needsMessageProcessing ||
        messages.length != _processedMessages.length) {
      _processMessages(messages, cleanText);
    }

    if (_processedMessages.isEmpty) {
      return const Center(
        child: Text('No messages yet', style: TextStyle(color: Colors.white)),
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
                    padding: const EdgeInsets.only(
                      left: 8.0,
                      right: 8.0,
                      top: 4.0,
                      bottom:
                          10.0, // Further reduced bottom padding to bring messages closer to input bar
                    ),
                    itemCount: _processedMessages.length +
                        (scrollController.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      debugPrint(
                          'DEBUG ChatUIManager: Building item $index, processedMessages length: ${_processedMessages.length}');
                      // Show loading indicator at the top (for loading older messages)
                      if (scrollController.isLoadingMore &&
                          index == _processedMessages.length) {
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
                          scrollController.isLoadingMore ? index - 1 : index;
                      if (messageGroupIndex < 0 ||
                          messageGroupIndex >= _processedMessages.length) {
                        return const SizedBox.shrink();
                      }
                      final messageGroup = _processedMessages[messageGroupIndex]
                          as MessageGroupData;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Stack(
                          children: [
                            Transform.translate(
                              offset: Offset(offset, 0),
                              child: MessageGroup(
                                messages: [
                                  messageGroup.parentMessage,
                                  ...messageGroup.replies
                                ],
                                showSender: true,
                                showTimestamp: messageGroup
                                    .parentMessage.shouldShowTimestamp,
                                showReadIndicator: false,
                                onTap: onMessageTap,
                                onLongPress: () {},
                                sendingStatus: {},
                                chatGroupId: chatGroupId,
                                chatType: chatType,
                                chatService: _chatService,
                                squadId: chatType == ChatType.squad
                                    ? chatGroupId
                                    : null,
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
                                      _formatTimestamp(
                                          messageGroup.parentMessage.timestamp),
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
  }

  Widget buildReplyPreview(BuildContext context, dynamic chatState,
      dynamic squadState, ChatType chatType, VoidCallback onClearReply) {
    final replyMessage = chatState.replyToMessage;
    if (replyMessage == null) return const SizedBox.shrink();

    // Create MessageData directly from Message entity
    final displayName =
        squadState.memberDisplayNames[replyMessage.senderId] ?? 'Unknown';
    final messageData = MessageData(
      id: replyMessage.id,
      sender: displayName,
      senderUid: replyMessage.senderId,
      text: replyMessage.text,
      content: replyMessage.text,
      timestamp: replyMessage.timestamp,
      delivered: true,
      read: true,
      reactions: replyMessage.reactions?.entries
              .map((e) => {'emoji': e.key, 'count': e.value, 'users': []})
              .toList() ??
          [],
      type: md.MessageType.text, // Use MessageData.MessageType
      status: md.MessageStatus.sent,
    );

    // Determine if the reply message is from the current user
    final currentUser = AuthServiceSupabase().currentUser;
    final isMe = replyMessage.senderId == currentUser?.id;

    // Format the timestamp
    final formattedTime = _formatTimestamp(replyMessage.timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date and time centered above
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                formattedTime,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // "Replying to" text positioned left or right
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                'Replying to $displayName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // The reply preview bubble
          GestureDetector(
            onTap: onClearReply,
            behavior: HitTestBehavior.translucent,
            child: MessageBubble(
              message: messageData,
              isMe: isMe,
              showSender: false,
              showAvatar: !isMe,
              showTimestamp: false,
              showReadIndicator: false,
              isFirstInGroup: true,
              isLastInGroup: true,
              onTap: () {},
              onLongPress: () {},
              sendingStatus: const {},
              chatType: chatType,
              squadId: chatType == ChatType.squad
                  ? squadState.selectedLobbyId
                  : null,
            ),
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
      List<Message> messages, String Function(String) cleanText) {
    // Filter out deleted messages before processing
    final visibleMessages =
        messages.where((message) => message.isDeleted != true).toList();

    // Convert messages to MessageData objects
    final messageDataList = visibleMessages.map((message) {
      final json = message.toJson();
      debugPrint(
          'DEBUG ChatUIManager: Processing message ${message.id}, text: "${message.text}", json keys: ${json.keys.toList()}');
      final messageData = MessageData.fromMap(json);
      debugPrint(
          'DEBUG ChatUIManager: Created MessageData with text: "${messageData.text}", hasContent: ${messageData.hasContent}');
      return messageData;
    }).toList();

    // Sort messages by timestamp (oldest first, newest at bottom for chat UI)
    messageDataList.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Mark messages that should show timestamps based on time gaps
    const int timeGapThresholdMinutes =
        30; // Show timestamp if gap > 30 minutes

    for (int i = 0; i < messageDataList.length; i++) {
      final message = messageDataList[i];
      if (i == 0) {
        // First (oldest) message always shows timestamp
        message.shouldShowTimestamp = true;
      } else {
        final prevMessage = messageDataList[i - 1];
        final timeDifference =
            message.timestamp.difference(prevMessage.timestamp).abs();
        if (timeDifference.inMinutes >= timeGapThresholdMinutes) {
          message.shouldShowTimestamp = true;
        } else {
          message.shouldShowTimestamp = false;
        }
      }
    }

    // Create message groups with threading support
    final List<MessageGroupData> messageGroups = [];
    final Map<String, MessageGroupData> messageGroupsById = {};

    // First pass: create groups for all messages
    for (final message in messageDataList) {
      messageGroupsById[message.id] = MessageGroupData(
        parentMessage: message,
        replies: [],
      );
    }

    // Second pass: organize into threads
    for (final message in messageDataList) {
      if (message.replyTo != null) {
        // This is a reply - add it to the parent message's group
        final parentGroup = messageGroupsById[message.replyTo];
        if (parentGroup != null) {
          parentGroup.replies.add(message);
        } else {
          // Parent not found, treat as standalone message
          messageGroups.add(messageGroupsById[message.id]!);
        }
      } else {
        // This is a root message
        messageGroups.add(messageGroupsById[message.id]!);
      }
    }

    // Sort replies within each group by timestamp
    for (final group in messageGroups) {
      group.replies.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    // Sort messages by timestamp (oldest first for display)
    messageGroups.sort((a, b) =>
        a.parentMessage.timestamp.compareTo(b.parentMessage.timestamp));

    _processedMessages = messageGroups;
    _needsMessageProcessing = false;
  }

  /// Show chat options menu
  void _showChatOptionsMenu({
    required BuildContext context,
    required String? chatGroupId,
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
        showSearch(
          context: context,
          delegate: ChatMessageSearchDelegate(),
        );
      },
      onChangeChatName: onChangeChatName,
      onChangeChatImage: onChangeChatImage,
      onClearChat: onClearChat,
      onQuickReactionPicker: onQuickReactionPicker,
      onToggleNotifications: onToggleNotifications,
      isMuted: _isMuted,
      onViewGroupInfo: onViewGroupInfo,
      onReportBug: onReportBug,
      onLeaveGroup: onLeaveGroup,
      onViewMediaGallery: onViewMediaGallery,
    );
  }
}
