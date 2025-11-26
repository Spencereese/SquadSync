import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async'; // Added for StreamSubscription

import '../utils.dart';
import '../providers.dart';

import 'chat_input_bar.dart';
import 'peacock_modal.dart';
import 'poll_creation_dialog.dart';
import '../screens/squad_tab_screen.dart';
import 'services/chat_initialization_service.dart';
import 'services/chat_scroll_controller.dart';
import 'services/chat_media_handler.dart';
import 'services/chat_typing_manager.dart';
import 'services/chat_ui_manager.dart';
import '../presentation/notifiers/chat_notifier.dart' as cn;
import '../domain/entities/chat_state.dart' as cn_state;
import '../domain/entities/chat_state.dart' as cs;
import '../domain/entities/message.dart' as msg;
import '../domain/entities/message.dart' show ChatType;
import '../presentation/notifiers/squad_notifier.dart' as sn;
import '../domain/entities/squad_state.dart';
import 'chat_settings_menu.dart'; // Importing ChatSettingsMenu
import 'media_history_screen.dart'; // Importing MediaHistoryScreen
import 'dialogs/invite_members_dialog.dart';

class ChatScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Service instances
  late final ChatInitializationService _initializationService;
  late final ChatScrollController _scrollControllerService;
  late final ChatMediaHandler _mediaHandler;
  late final ChatTypingManager _typingManager;
  late final ChatUIManager _uiManager;

  late AnimationController _animationController;
  late ScrollController _scrollController;
  String _chatName = 'Squad Chat';
  String? _chatImageUrl;

  bool _isMuted = false;

  bool get isUserGroup => widget.chatType == ChatType.userGroup;
  bool get isDM => widget.chatType == ChatType.dm;

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
        .replaceAll('â€™', "'") // Curly apostrophe
        .replaceAll('â€œ', '"') // Left double quote
        .replaceAll('â€', '"') // Right double quote
        .replaceAll('â€™', "'") // Right single quote
        .replaceAll('â€', '-') // Em dash
        .replaceAll('â€¦', '...') // Ellipsis
        .replaceAll('ðŸ' + 'â' + '¹', '👍') // Thumbs up
        .replaceAll('ðŸ˜' + '‚', '😂') // Laughing
        .replaceAll('ðŸ˜' + '¢', '😢') // Sad
        .replaceAll('ðŸ˜' + '¡', '😡') // Angry
        .replaceAll('â€¤ï¸' + '�', '❤️') // Heart
        .replaceAll('ð', '👍') // Generic corrupted emoji fallback
        .replaceAll('ð®', '❤️'); // Another common corruption
  }

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
    _mediaHandler = ChatMediaHandler();
    _typingManager = ChatTypingManager();
    _uiManager = ChatUIManager();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scrollController = ScrollController();

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Safety check: prevent opening chat with null chatGroupId for user groups
    if (widget.chatType == ChatType.userGroup && widget.chatGroupId == null) {
      debugPrint(
          'DEBUG ChatScreen: Invalid user group chat initialization with null chatGroupId, popping');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          showSnackBar(context, 'Unable to open group chat');
        }
      });
      return;
    }

    // Save this chat group as the last used chat group
    if (widget.chatType == ChatType.userGroup && widget.chatGroupId != null) {
      _saveLastChatGroup(widget.chatGroupId!);
    }

    // Set chat name from widget parameters if provided (for chat groups)
    if (widget.chatGroupName != null) {
      _chatName = widget.chatGroupName!;
    }

    // Initialize UI manager with current state AFTER setting the correct chat name
    _uiManager.initialize(
      initialChatName: _chatName,
      initialChatImageUrl: _chatImageUrl,
      initialIsMuted: _isMuted,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize provider-dependent services here, after the widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Use initialization service for complex setup
      _initializationService.initializeChat(
        context: context,
        ref: ref,
        chatGroupId: widget.chatGroupId,
        chatGroupName: widget.chatGroupName,
        chatType: widget.chatType,
        setChatName: (name) {
          if (mounted) setState(() => _chatName = name);
          _uiManager.chatName = name;
        },
        setChatImageUrl: (url) {
          if (mounted) setState(() => _chatImageUrl = url);
          _uiManager.chatImageUrl = url;
        },
        loadMoreMessages: _loadMoreMessages,
        scrollToBottom: _scrollToBottom,
        sendMessage: (message) {
          _messageController.text = message;
          _sendMessage(null);
        },
        messageController: _messageController,
        initialMessage: widget.initialMessage,
      );

      // Load messages using the new ChatNotifier
      ref
          .read(cn.chatNotifierProvider.notifier)
          .selectChatGroup(widget.chatGroupId);
      ref.read(cn.chatNotifierProvider.notifier).loadMessages(
            widget.chatGroupId!,
          );
    });

    // Initialize scroll controller with callbacks
    _scrollControllerService.initialize(
      onScrollChanged: () => mounted ? setState(() {}) : null,
      onLoadMoreMessages: _loadMoreMessages,
    );

    // Initialize typing manager
    _typingManager.initializeTypingListener(
      ref,
      chatGroupId: widget.chatGroupId,
      chatType: widget.chatType,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100 &&
        !_scrollController.position.atEdge) {
      // User scrolled near the top, trigger pagination
      // ref.read(cn.chatNotifierProvider.notifier).paginateMore();
    }
  }

  @override
  void dispose() {
    _scrollControllerService.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    _inputFocusNode.dispose();
    _animationController.dispose();
    _mediaHandler.dispose();
    _typingManager.dispose();
    _saveDraftForHandoff();
    super.dispose();
  }

  void _handleSyncStateChanges(cs.ChatState chatState) {
    // Handle sync error notifications
    if (chatState.syncError != null && chatState.syncError!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync error: ${chatState.syncError}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              ref.read(cn.chatNotifierProvider.notifier).performSync();
            },
          ),
        ),
      );
      // Clear the error after showing
      ref.read(cn.chatNotifierProvider.notifier).clearSyncError();
    }

    // Handle sync completion with haptic feedback
    if (!chatState.isSyncing && _previousSyncState == true) {
      HapticFeedback.lightImpact();
      if (chatState.syncConflicts.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed with conflicts resolved'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    // Update previous sync state
    _previousSyncState = chatState.isSyncing;
  }

  bool? _previousSyncState;

  Future<void> _loadMoreMessages() async {
    await _scrollControllerService.loadMoreMessages(
      chatGroupId: widget.chatGroupId,
      onStateChanged: () => mounted ? setState(() {}) : null,
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

  Future<void> _sendMessage(msg.Message? replyToMessage,
      [SquadState? squadState]) async {
    if (_messageController.text.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }

    // Handle commands
    if (_messageController.text.startsWith('/')) {
      await _handleCommand(_messageController.text);
      _messageController.clear();
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await ref.read(cn.chatNotifierProvider.notifier).sendMessage(
            widget.chatGroupId!,
            _messageController.text,
            msg.MessageType.text,
            widget.chatType,
            replyTo: replyToMessage?.id,
          );

      // Message sent successfully
      _messageController.clear();
      // Clear reply after sending
      ref.read(cn.chatNotifierProvider.notifier).clearReplyToMessage();
      // Add haptic feedback for successful send
      HapticFeedback.lightImpact();
      await _typingManager.onMessageSent(
        ref,
        chatGroupId: widget.chatGroupId,
      );
      _scrollToBottom();
      await _checkFirstMessage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
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
    await _mediaHandler.sendMedia(ref,
        chatGroupId: widget.chatGroupId, chatType: widget.chatType);
  }

  Future<void> _startRecording() async {
    await _mediaHandler.startRecording(ref);
    _animationController.repeat();
  }

  Future<void> _stopRecording() async {
    await _mediaHandler.stopRecording(ref,
        chatGroupId: widget.chatGroupId, chatType: widget.chatType);
    _animationController.stop();
  }

  Future<void> _saveLastChatGroup(String chatGroupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_chat_group', chatGroupId);
      debugPrint('Saved last chat group: $chatGroupId');
    } catch (e) {
      debugPrint('Error saving last chat group: $e');
    }
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

  void _viewGroupInfo(SquadState squadStateData) {
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
                        Text(
                          '${squadStateData.globalStatuses.length} members',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
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
                    'This is a group chat for $_chatName. You can customize this description in group settings.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Members section - clickable cards at top
                  const Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children:
                        squadStateData.globalStatuses.entries.map((entry) {
                      final uid = entry.key;
                      final status = entry.value;
                      final displayName =
                          squadStateData.memberDisplayNames[uid] ?? 'Unknown';
                      final banCount =
                          0; // TODO: Implement ban count in new architecture

                      return GestureDetector(
                        onTap: () => _showMemberMenu(
                            context, displayName, squadStateData),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                child: Text(
                                    displayName.substring(0, 1).toUpperCase()),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (banCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    '$banCount ban${banCount != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              const Icon(
                                Icons.more_vert,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMemberMenu(
      BuildContext context, String userName, SquadState squadState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User's name
            Text(
              userName,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            // Options
            _buildMemberMenuItem(
              context,
              icon: Icons.videocam,
              label: 'Video Call',
              onTap: () {
                // TODO: Implement video call
                Navigator.pop(context);
              },
            ),
            _buildMemberMenuItem(
              context,
              icon: Icons.call,
              label: 'Audio Call',
              onTap: () {
                // TODO: Implement audio call
                Navigator.pop(context);
              },
            ),
            _buildMemberMenuItem(
              context,
              icon: Icons.message,
              label: 'Message',
              onTap: () {
                // TODO: Open 1-on-1 message
                Navigator.pop(context);
              },
            ),
            _buildMemberMenuItem(
              context,
              icon: Icons.gavel,
              label: 'Ban',
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement ban functionality in new Riverpod architecture
                // squadState.addBan(userName, ref.watch(userNotifierProvider.select((asyncValue) => asyncValue.value?.displayName ?? 'Unknown')));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$userName has been voted for ban')),
                );
              },
            ),
            _buildMemberMenuItem(
              context,
              icon: Icons.person_off,
              label: 'Block User',
              onTap: () async {
                Navigator.pop(context);
                // TODO: Implement block functionality in new Riverpod architecture
                // await squadState.blockUser(userName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$userName has been blocked')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberMenuItem(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  void _inviteMembers() {
    if (!mounted || widget.chatGroupId == null) return;

    showDialog(
      context: context,
      builder: (context) => InviteMembersDialog(
        chatGroupId: widget.chatGroupId!,
        chatGroupName: _chatName,
        isSquadGroup: widget.chatType == ChatType.userGroup,
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
      await ref
          .read(cn.chatNotifierProvider.notifier)
          .leaveGroup(widget.chatGroupId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('You left "${widget.chatGroupName ?? 'the group'}"')),
        );
        // Navigate back to the previous screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave group: $e')),
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

  @override
  Widget build(BuildContext context) {
    // Watch Riverpod providers
    final squadStateData = ref.watch(sn.squadNotifierProvider);
    final chatStateData = ref.watch(cn.chatNotifierProvider);

    return squadStateData.when(
      data: (squadState) => chatStateData.when(
        data: (chatState) {
          // Monitor sync state changes for UI feedback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleSyncStateChanges(chatState);
          });

          return SafeArea(
            top: true,
            bottom: false,
            child: Scaffold(
              body: _buildChatContent(context, squadState, chatState),
            ),
          );
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showErrorSnackBar(context, 'Failed to load chat data: $error');
          });
          return Scaffold(
            body: Center(child: Text('Error: $error')),
          );
        },
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showErrorSnackBar(context, 'Failed to load squad data: $error');
        });
        return Scaffold(
          body: Center(child: Text('Error: $error')),
        );
      },
    );
  }

  Widget _buildChatContent(BuildContext context, SquadState squadStateData,
      cn_state.ChatState chatStateData) {
    // Use the passed chatStateData instead of Provider.of for Riverpod migration
    final chatState = chatStateData;
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
        child: GestureDetector(
          onTap: () => FocusScope.of(context)
              .unfocus(), // Dismiss keyboard when tapping chat area
          child: Stack(
            children: [
              Column(
                children: [
                  _uiManager
                      .buildChatHeader(
                        context: context,
                        chatGroupId: widget.chatGroupId,
                        onBackPressed: () => Navigator.pop(context),
                        onToggleNotifications: _toggleNotifications,
                        onViewGroupInfo: () => _viewGroupInfo(squadStateData),
                        onReportBug: _reportBug,
                        onLeaveGroup: _leaveGroup,
                        onInviteMembers: _inviteMembers,
                        onChangeChatName: () async {
                          ChatSettingsMenu.showChangeChatNameDialog(
                            context: context,
                            currentName: _chatName,
                            onSave: (newName) async {
                              if (widget.chatGroupId != null) {
                                try {
                                  // User group: update in users/{uid}/chat_groups/{groupId}
                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;
                                  if (currentUser == null) return;

                                  final groupRef = FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(currentUser.uid)
                                      .collection('chat_groups')
                                      .doc(widget.chatGroupId!);

                                  // Update the chat group name in Firestore
                                  await groupRef.set({
                                    'name': newName,
                                    'timestamp': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));

                                  // Update local state
                                  if (mounted) {
                                    setState(() => _chatName = newName);
                                  }
                                  // Update UI manager
                                  _uiManager.chatName = newName;

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Chat name updated successfully'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error updating chat name: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to update chat name: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          );
                        },
                        onChangeChatImage: () async {
                          await _mediaHandler.changeChatImage(
                            context,
                            chatGroupId: widget.chatGroupId,
                            onImageUpdated: (url) => mounted
                                ? setState(() => _chatImageUrl = url)
                                : null,
                          );
                        },
                        onClearChat: () async {
                          // This will be implemented when we integrate with ChatSettingsMenu
                        },
                        onQuickReactionPicker: () {
                          // This will be implemented when we integrate with ChatSettingsMenu
                        },
                        onViewMediaGallery: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MediaHistoryScreen(
                                chatGroupId: widget.chatGroupId,
                                chatType: widget.chatType,
                              ),
                            ),
                          );
                        },
                      )
                      .animate()
                      .fadeIn(),
                  // Active Squad Header Card
                  _uiManager.buildActiveSquadHeader(context,
                      chatGroupId: widget.chatGroupId),
                  // Available Squads Widget
                  // const AvailableSquadsWidget(), // Removed - keeping only "Your Active Squad" widget
                  Expanded(
                    child: _uiManager.buildMessagesList(
                      ref: ref,
                      chatGroupId: widget.chatGroupId,
                      chatType: widget.chatType,
                      scrollController: _scrollControllerService,
                      onMessageLongPress: () {}, // Will be implemented
                      onMessageTap: () {}, // Will be implemented
                      getSender: _getSender,
                      getTimestampMs: _getTimestampMs,
                      cleanText: _cleanText,
                      markAsDelivered:
                          ref.read(chatServiceProvider).markAsDelivered,
                    ),
                  ),
                ],
              ),
              ...(chatState.replyToMessage != null
                  ? [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => ref
                              .read(cn.chatNotifierProvider.notifier)
                              .clearReplyToMessage(),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                    ]
                  : []),
              // Input bar positioned at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Semantics(
                  label: 'Chat input bar',
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: bottomPadding,
                      left: 8.0,
                      right: 8.0,
                    ),
                    child: ChatInputBar(
                      controller: _messageController,
                      focusNode: _inputFocusNode,
                      isRecording: chatState.isRecording,
                      isUploading: chatState.isUploading,
                      onSend: () => _sendMessage(
                          chatState.replyToMessage, squadStateData),
                      onMedia: _sendMedia,
                      onRecordStart: _startRecording,
                      onRecordStop: _stopRecording,
                      onPlusMenu: () => _showPlusMenu(context),
                      onTextChanged: (value) {
                        _typingManager.onTextChanged(
                          value,
                          ref,
                          chatGroupId: widget.chatGroupId,
                        );
                      },
                      quickReactionEmoji: chatState.quickReactionEmoji,
                      hintText: chatState.replyToMessage != null
                          ? 'Reply'
                          : 'Message',
                    ),
                  ),
                ),
              ),
              // Reply preview positioned above input bar
              ...(chatState.replyToMessage != null
                  ? [
                      Positioned(
                        bottom: 80, // Position above input bar
                        left: 0,
                        right: 0,
                        child: _uiManager.buildReplyPreview(
                          context,
                          chatState,
                          squadStateData,
                          widget.chatType,
                          () => ref
                              .read(cn.chatNotifierProvider.notifier)
                              .clearReplyToMessage(),
                        ),
                      ),
                    ]
                  : []),
            ],
          ),
        ),
      ),
    );
  }
}
