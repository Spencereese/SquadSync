import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Added for utf8
import 'dart:async'; // Added for StreamSubscription

import '../utils.dart';
import '../squad_state.dart';
import '../services/ai_service.dart';
import 'chat_input_bar.dart';
import 'chat_service.dart';

import 'chat_state.dart';
import 'dialogs/invite_members_dialog.dart';

import 'peacock_modal.dart';
import 'poll_creation_dialog.dart';
import '../screens/squad_tab_screen.dart';
import 'services/chat_initialization_service.dart';
import 'services/chat_scroll_controller.dart';
import 'services/chat_online_status_manager.dart';
import 'services/chat_media_handler.dart';
import 'services/chat_typing_manager.dart';
import 'services/chat_ui_manager.dart';
// import 'available_squads_widget.dart'; // Removed - no longer used

class ChatScreen extends StatefulWidget {
  final String? initialMessage;
  final String? chatGroupId;
  final String? chatGroupName;
  final ChatType chatType;
  const ChatScreen(
      {super.key,
      this.initialMessage,
      this.chatGroupId,
      this.chatGroupName,
      required this.chatType});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Service instances
  late final ChatInitializationService _initializationService;
  late final ChatScrollController _scrollControllerService;
  late final ChatOnlineStatusManager _onlineStatusManager;
  late final ChatMediaHandler _mediaHandler;
  late final ChatTypingManager _typingManager;
  late final ChatUIManager _uiManager;

  late AnimationController _animationController;
  String _chatName = 'Squad Chat';
  String? _chatImageUrl;
  final ChatService _chatService = ChatService();
  late SquadState _squadState;
  bool _isMuted = false;

  // Cache for user display names to avoid FutureBuilder in ListView

  // Cache for processed messages to avoid expensive operations in build
  bool get isUserGroup => widget.chatType == ChatType.userGroup;
  bool get isDM => widget.chatType == ChatType.dm;

  @override
  void initState() {
    super.initState();
    debugPrint(
        'DEBUG ChatScreen.initState: widget.chatGroupId = ${widget.chatGroupId}');
    debugPrint(
        'DEBUG ChatScreen.initState: widget.chatType = ${widget.chatType}');
    debugPrint('DEBUG ChatScreen.initState: isDM = $isDM');
    debugPrint('DEBUG ChatScreen.initState: isUserGroup = $isUserGroup');

    // Initialize services
    _initializationService = ChatInitializationService();
    _scrollControllerService = ChatScrollController();
    _onlineStatusManager = ChatOnlineStatusManager();
    _mediaHandler = ChatMediaHandler();
    _typingManager = ChatTypingManager();
    _uiManager = ChatUIManager();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize UI manager with current state
    _uiManager.initialize(
      initialChatName: _chatName,
      initialChatImageUrl: _chatImageUrl,
      initialIsMuted: _isMuted,
    );
    _squadState = Provider.of<SquadState>(context, listen: false);

    // Safety check: prevent opening squad chat with null chatGroupId
    if (widget.chatType == ChatType.squad && widget.chatGroupId == null) {
      debugPrint(
          'DEBUG ChatScreen: Invalid squad chat initialization with null chatGroupId, popping');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          showSnackBar(context, 'Unable to open squad chat');
        }
      });
      return;
    }

    // Set chat name from widget parameters if provided (for chat groups)
    if (widget.chatGroupName != null) {
      _chatName = widget.chatGroupName!;
    }

    // Defer heavy operations to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Use initialization service for complex setup
      _initializationService.initializeChat(
        context: context,
        chatGroupId: widget.chatGroupId,
        chatGroupName: widget.chatGroupName,
        chatType: widget.chatType,
        setChatName: (name) => setState(() => _chatName = name),
        setChatImageUrl: (url) => setState(() => _chatImageUrl = url),
        loadMoreMessages: _loadMoreMessages,
        scrollToBottom: _scrollToBottom,
        sendMessage: (message) {
          _messageController.text = message;
          _sendMessage();
        },
        messageController: _messageController,
        initialMessage: widget.initialMessage,
      );
    });

    // Initialize scroll controller with callbacks
    _scrollControllerService.initialize(
      onScrollChanged: () => setState(() {}),
      onLoadMoreMessages: _loadMoreMessages,
    );

    // Initialize typing manager
    _typingManager.initializeTypingListener(
      context,
      chatGroupId: widget.chatGroupId,
      chatType: widget.chatType,
      squadState: _squadState,
    );
  }

  @override
  void dispose() {
    _onlineStatusManager.updateOnlineStatus(false, _squadState);
    _scrollControllerService.dispose();
    _messageController.dispose();
    _animationController.dispose();
    _mediaHandler.dispose();
    _typingManager.dispose();
    _saveDraftForHandoff();
    super.dispose();
  }

  Future<void> _loadMoreMessages() async {
    await _scrollControllerService.loadMoreMessages(
      chatGroupId: widget.chatGroupId,
      onStateChanged: () => setState(() {}),
    );
  }

  void _scrollToBottom() {
    _scrollControllerService.scrollToBottom();
  }

  Future<void> _toggleNotifications() async {
    if (!mounted) return;
    final wasMuted = _isMuted;
    setState(() {
      _isMuted = !_isMuted;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chat_muted', _isMuted);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  _isMuted ? 'Notifications muted' : 'Notifications unmuted')),
        );
      }
    } catch (e) {
      // Revert state on error
      if (mounted) {
        setState(() {
          _isMuted = wasMuted;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }

    final capturedContext = context;

    // Handle commands
    if (_messageController.text.startsWith('/')) {
      await _handleCommand(_messageController.text);
      _messageController.clear();
      return;
    }

    final chatState = Provider.of<ChatState>(context, listen: false);
    String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    chatState.updateSendingStatus(tempId, true);

    // Get reply information
    final replyTo = chatState.replyToMessage?['id'] as String?;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final result = await _chatService.sendMessage(capturedContext,
          senderUid: user.uid,
          text: _messageController.text,
          replyTo: replyTo,
          chatGroupId: widget.chatGroupId,
          chatType: widget.chatType);

      if (result.success) {
        if (result.isOffline && mounted) {
          ScaffoldMessenger.of(capturedContext).showSnackBar(
            const SnackBar(
                content: Text('Message queued for sending when online')),
          );
        }
        chatState.removeSendingStatus(tempId);
        _messageController.clear();
        // Clear reply after sending
        chatState.clearReplyToMessage();
        await _typingManager.onMessageSent(
          capturedContext,
          chatGroupId: widget.chatGroupId,
          squadState: _squadState,
        );
        _scrollToBottom();
        await _checkFirstMessage();
      } else {
        // Handle failure
        if (mounted) {
          ScaffoldMessenger.of(capturedContext).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? 'Send failed')),
          );
          chatState.updateSendingStatus(tempId, false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
        chatState.updateSendingStatus(tempId, false);
      }
    }
  }

  Future<void> _handleCommand(String command) async {
    if (command.toLowerCase().startsWith('/peacock')) {
      _showPeacockModal(context);
    }
    // Add other commands here if needed
  }

  Future<void> _sendMedia() async {
    await _mediaHandler.sendMedia(context,
        chatGroupId: widget.chatGroupId, chatType: widget.chatType);
  }

  Future<void> _startRecording() async {
    await _mediaHandler.startRecording(context);
    _animationController.repeat();
  }

  Future<void> _stopRecording() async {
    await _mediaHandler.stopRecording(context,
        chatGroupId: widget.chatGroupId, chatType: widget.chatType);
    _animationController.stop();
  }

  Future<void> _checkFirstMessage() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('first_message_sent')) {
        await prefs.setBool('first_message_sent', true);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
                  const SnackBar(content: Text('🎉 First message sent!')))
              .closed
              .then((_) => Animate(
                    effects: const [
                      FadeEffect(duration: Duration(milliseconds: 500))
                    ],
                    child: const Text(''),
                  ));
        }
      }
    } catch (e) {
      // Silently handle error - this is not critical
    }
  }

  Future<void> _saveDraftForHandoff() async {
    final prefs = await SharedPreferences.getInstance();
    if (_messageController.text.isNotEmpty) {
      await prefs.setString('chat_draft', _messageController.text);
    } else {
      await prefs.remove('chat_draft');
    }
  }

  void _viewGroupInfo() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Group Info'),
            backgroundColor: Colors.black,
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.indigo],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group header
                  Center(
                    child: Column(
                      children: [
                        if (_chatImageUrl != null)
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: NetworkImage(_chatImageUrl!),
                          )
                        else
                          const CircleAvatar(
                            radius: 50,
                            child: Icon(
                              Icons.group,
                              color: Colors.cyanAccent,
                              size: 50,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          _chatName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Consumer<SquadState>(
                          builder: (context, squadState, _) {
                            final memberCount = squadState.statuses.length;
                            return Text(
                              '$memberCount members',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Group description (placeholder for now)
                  const Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is a group chat for ${_chatName}. You can customize this description in group settings.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Members section
                  const Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer<SquadState>(
                    builder: (context, squadState, _) {
                      final members = squadState.statuses.entries.map((entry) {
                        final uid = entry.key;
                        final status = entry.value;
                        final displayName =
                            squadState.getDisplayNameForUid(uid);
                        return ListTile(
                          leading: CircleAvatar(
                            child:
                                Text(displayName.substring(0, 1).toUpperCase()),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            status,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList();

                      return Column(children: members);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _inviteMembers() {
    if (!mounted || widget.chatGroupId == null) return;

    showDialog(
      context: context,
      builder: (context) => InviteMembersDialog(
        chatGroupId: widget.chatGroupId!,
        chatGroupName: _chatName,
        isSquadGroup: widget.chatType == ChatType.squad,
      ),
    );
  }

  void _reportBug() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bug report submitted')),
    );
  }

  void _leaveGroup() async {
    if (!mounted) return;
    try {
      await _squadState.leaveSquad();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the squad')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave squad: $e')),
        );
      }
    }
  }

  void _showPlusMenu(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Photo options row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPlusMenuItem(
                  icon: Icons.photo_library,
                  label: 'Photos',
                  onTap: () {
                    Navigator.pop(context);
                    _sendMedia();
                  },
                ),
                _buildPlusMenuItem(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _sendMedia();
                  },
                ),
                _buildPlusMenuItem(
                  icon: Icons.location_on,
                  label: 'Location',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.grey, height: 1),
          ListTile(
            leading: const Icon(Icons.poll, color: Colors.white),
            title: const Text('Create Poll',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              PollCreationDialog.show(context,
                  chatGroupId: widget.chatGroupId, chatType: widget.chatType);
            },
          ),
          ListTile(
            leading: const Icon(Icons.flash_on, color: Colors.white),
            title:
                const Text('Squad Up', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SquadTabScreen(chatGroupId: widget.chatGroupId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlusMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context, String typingUser) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Animated typing dots like iMessage
          SizedBox(
            width: 24,
            height: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 600 + (index * 200)),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, -4 * (value * 2 - 1).abs() + 2),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$typingUser is typing...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _showPeacockModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: PeacockModal(),
        );
      },
    );
  }

  int? _getTimestampMs(dynamic message) {
    if (message is DocumentSnapshot) {
      final data = message.data() as Map<String, dynamic>?;
      if (data?['timestamp'] is Timestamp) {
        return (data?['timestamp'] as Timestamp).millisecondsSinceEpoch;
      }
      return data?['timestamp_ms'] as int?;
    } else if (message is Map<String, dynamic>) {
      return message['timestamp_ms'] as int?;
    }
    return null;
  }

  String? _getSender(dynamic message) {
    if (message is DocumentSnapshot) {
      final data = message.data() as Map<String, dynamic>?;
      return data?['senderUid'] as String?;
    } else if (message is Map<String, dynamic>) {
      return message['senderUid'] as String?;
    }
    return null;
  }

  String _cleanText(String text) {
    // Force UTF-8 decoding if needed, but since from Firestore, replace common garbled patterns
    try {
      // If text is garbled, attempt to re-encode/decode
      final bytes = latin1.encode(text); // Assume wrong encoding
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {}
    // Manual replacements for common Messenger corruptions
    return text
        .replaceAll('â’', "'") // Curly apostrophe
        .replaceAll('â“', '"') // Left double quote
        .replaceAll('â”', '"') // Right double quote
        .replaceAll('â’', "'") // Right single quote
        .replaceAll('â€', '-') // Em dash
        .replaceAll('â…', '...') // Ellipsis
        .replaceAll('ðŸ‘�', '👍') // Thumbs up
        .replaceAll('ðŸ˜‚', '😂') // Laughing
        .replaceAll('ðŸ˜¢', '😢') // Sad
        .replaceAll('ðŸ˜¡', '😡') // Angry
        .replaceAll('â�¤ï¸�', '❤️') // Heart
        .replaceAll('ð', '👍') // Generic corrupted emoji fallback
        .replaceAll('ð®', '❤️'); // Another common corruption
  }

  @override
  Widget build(BuildContext context) {
    // Chat should work regardless of squad selection status
    return SafeArea(
      top: true,
      bottom: false,
      child: Scaffold(
        body: Consumer<ChatState>(
          builder: (context, chatState, _) {
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            final bottomPadding = keyboardHeight > 0 ? keyboardHeight : 16.0;
            return MediaQuery.removePadding(
              context: context,
              removeBottom: keyboardHeight > 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.indigo],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _uiManager
                            .buildChatHeader(
                              context: context,
                              chatGroupId: widget.chatGroupId,
                              squadState: _squadState,
                              onBackPressed: () => Navigator.pop(context),
                              onToggleNotifications: _toggleNotifications,
                              onViewGroupInfo: _viewGroupInfo,
                              onReportBug: _reportBug,
                              onLeaveGroup: _leaveGroup,
                              onInviteMembers: _inviteMembers,
                              onChangeChatName: () async {
                                // This will be implemented when we integrate with ChatSettingsMenu
                              },
                              onChangeChatImage: () async {
                                await _mediaHandler.changeChatImage(
                                  context,
                                  chatGroupId: widget.chatGroupId,
                                  squadState: _squadState,
                                  onImageUpdated: (url) =>
                                      setState(() => _chatImageUrl = url),
                                );
                              },
                              onClearChat: () async {
                                // This will be implemented when we integrate with ChatSettingsMenu
                              },
                              onQuickReactionPicker: () {
                                // This will be implemented when we integrate with ChatSettingsMenu
                              },
                            )
                            .animate()
                            .fadeIn(),
                        // Active Squad Header Card
                        _uiManager.buildActiveSquadHeader(context),
                        // Available Squads Widget
                        // const AvailableSquadsWidget(), // Removed - keeping only "Your Active Squad" widget
                        Expanded(
                          child: _uiManager.buildMessagesList(
                            context: context,
                            chatGroupId: widget.chatGroupId,
                            chatType: widget.chatType,
                            scrollController: _scrollControllerService,
                            squadState: _squadState,
                            chatState: chatState,
                            onMessageLongPress: () {}, // Will be implemented
                            onMessageTap: () {}, // Will be implemented
                            getSender: _getSender,
                            getTimestampMs: _getTimestampMs,
                            cleanText: _cleanText,
                            markAsDelivered: _chatService.markAsDelivered,
                          ),
                        ),
                        // Reply preview
                        if (chatState.replyToMessage != null)
                          _uiManager.buildReplyPreview(context, chatState),
                        // Typing indicator
                        if (chatState.typingUser != null)
                          _buildTypingIndicator(context, chatState.typingUser!),
                        Semantics(
                          label: 'Chat input bar',
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: bottomPadding,
                              left: 8.0,
                              right: 8.0,
                            ),
                            child: ChatInputBar(
                              controller: _messageController,
                              isRecording: chatState.isRecording,
                              isUploading: chatState.isUploading,
                              onSend: _sendMessage,
                              onMedia: _sendMedia,
                              onRecordStart: _startRecording,
                              onRecordStop: _stopRecording,
                              onPlusMenu: () => _showPlusMenu(context),
                              onTextChanged: (value) {
                                _typingManager.onTextChanged(
                                  value,
                                  context,
                                  chatGroupId: widget.chatGroupId,
                                  squadState: _squadState,
                                );
                              },
                              quickReactionEmoji: chatState.quickReactionEmoji,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Jump to bottom button
                    if (_scrollControllerService.showJumpToBottom)
                      _uiManager.buildJumpToBottomButton(
                        bottomPadding: bottomPadding,
                        onJumpToBottom: _scrollToBottom,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        // Removed floating action button for peacock - now only in squad lobbies
      ),
    );
  }
}
