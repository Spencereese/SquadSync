import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async'; // Added for StreamSubscription

import '../utils.dart';
import '../services/background_service.dart';

import 'chat_input_bar.dart';
import 'peacock_modal.dart';
import 'poll_creation_dialog.dart';
import 'widgets/chat_lobby_sheet.dart';
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
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../domain/entities/lobby_state.dart';
import 'widgets/neon_chat_app_bar.dart';
import 'screens/chat_info_screen.dart';
import '../presentation/notifiers/lobby_notifier.dart';

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
  final AuthServiceSupabase _auth = AuthServiceSupabase();

  // Service instances
  late final ChatInitializationService _initializationService;
  late final ChatScrollController _scrollControllerService;
  late final ChatMediaHandler _mediaHandler;
  late final ChatTypingManager _typingManager;
  late final ChatUIManager _uiManager;
  late final BackgroundService _backgroundService;

  late AnimationController _animationController;
  late ScrollController _scrollController;
  String _chatName = 'Lobby Chat';
  String? _chatImageUrl;
  String? _cachedBackgroundUrl;
  bool _backgroundImageLoaded = false;

  bool _isMuted = false;

  // Cache for lobbies future to prevent repeated fetches
  Future<List<Map<String, dynamic>>>? _lobbiesFuture;

  bool get isUserGroup => widget.chatType == ChatType.userGroup;
  bool get isDM => widget.chatType == ChatType.dm;

  String? get effectiveChatGroupId {
    if (widget.chatGroupId != null) return widget.chatGroupId;
    if (widget.chatType == ChatType.squad) {
      final squadAsync = ref.read(ln.lobbyNotifierProvider);
      return squadAsync.value?.selectedLobbyId;
    }
    return null;
  }

  int? _getTimestampMs(dynamic message) {
    if (message is Map<String, dynamic>) {
      // Handle both timestamp_ms (Supabase) and timestamp as ISO string
      if (message['timestamp_ms'] != null) {
        return message['timestamp_ms'] as int?;
      }
      if (message['timestamp'] is String) {
        return DateTime.parse(message['timestamp']).millisecondsSinceEpoch;
      }
    }
    return null;
  }

  String? _getSender(dynamic message) {
    if (message is Map<String, dynamic>) {
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

  /// Build a map of display names to avatar URLs for @ mentions
  Map<String, String> _buildMemberAvatarMap(LobbyState squadState) {
    final avatarMap = <String, String>{};

    // Map UIDs to display names and their profile images
    squadState.memberDisplayNames.forEach((uid, displayName) {
      final avatarUrl = squadState.memberProfileImages?[uid];
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        avatarMap[displayName] = avatarUrl;
      }
    });

    return avatarMap;
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
    _backgroundService = BackgroundService();

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
    debugPrint(
        '🔍 ChatScreen init: chatType=${widget.chatType}, chatGroupId=${widget.chatGroupId}');
    if (widget.chatType == ChatType.userGroup && widget.chatGroupId != null) {
      debugPrint('🔍 Conditions met for setting squad ID');
      _saveLastChatGroup(widget.chatGroupId!);
    } else {
      debugPrint(
          '⚠️ Conditions NOT met: chatType=${widget.chatType}, chatGroupId=${widget.chatGroupId}');
    }

    // Set chat name from widget parameters if provided (for chat groups)
    if (widget.chatGroupName != null) {
      _chatName = widget.chatGroupName!;
    }

    // Load mute status from local storage first
    _loadMuteStatus();

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

    // Set squad ID for user group chats by querying lobby table
    if (widget.chatType == ChatType.userGroup && widget.chatGroupId != null) {
      // Run async lobby query after frame builds to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        try {
          debugPrint(
              '🔍 Querying lobby for chat_group_id: ${widget.chatGroupId}');

          // Query lobby by chat_group_id
          final lobbyResponse = await SupabaseService.client
              .from('lobbies')
              .select()
              .eq('chat_group_id', widget.chatGroupId!)
              .maybeSingle();

          String lobbyId;

          if (lobbyResponse == null) {
            debugPrint(
                '⚠️ No lobby found for chat group, using chat_group_id as lobby_id');
            // If no lobby found, the lobby ID is the same as chat_group_id
            // (lobbies are created with id = chat_group_id in chat_remote_datasource_impl.dart)
            lobbyId = widget.chatGroupId!;
          } else {
            lobbyId = lobbyResponse['id'] as String;
            debugPrint(
                '✅ Found lobby: $lobbyId for chat_group_id: ${widget.chatGroupId}');
          }

          // Set the lobby ID in the notifier
          if (mounted) {
            final lobbyNotifier = ref.read(ln.lobbyNotifierProvider.notifier);
            lobbyNotifier.setSelectedLobbyId(lobbyId);
            debugPrint('✅ Set lobby ID in didChangeDependencies: $lobbyId');
          }
        } catch (e) {
          debugPrint(
              '❌ Error querying/setting lobby ID in didChangeDependencies: $e');
          // Fallback: use chat_group_id as lobby ID
          if (mounted) {
            final lobbyNotifier = ref.read(ln.lobbyNotifierProvider.notifier);
            lobbyNotifier.setSelectedLobbyId(widget.chatGroupId!);
            debugPrint(
                '⚠️ Fallback: Set chat_group_id as lobby ID: ${widget.chatGroupId}');
          }
        }
      });
    }

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

      // Initialize chat using the coordinator
      final chatGroupId = effectiveChatGroupId;
      if (chatGroupId != null) {
        ref
            .read(cn.chatNotifierProvider.notifier)
            .initializeChat(chatGroupId, widget.chatType)
            .catchError((error) {
          if (mounted) {
            // Extract user-friendly error message
            String errorMsg = error.toString();
            if (errorMsg.contains('ChannelRateLimitReached')) {
              errorMsg = 'Too many connections. Cleaning up...';
              // Auto-cleanup channels
              SupabaseService.dispose();
              // Auto-retry after cleanup
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  ref
                      .read(cn.chatNotifierProvider.notifier)
                      .initializeChat(chatGroupId, widget.chatType);
                }
              });
            } else if (errorMsg.contains('channelError')) {
              errorMsg =
                  'Connection issue. Chat will work with limited features.';
            } else {
              errorMsg = 'Connection issue. Retrying...';
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: errorMsg.contains('limited features')
                    ? Colors.orange
                    : Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
        });
      }
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
    // Clean up Supabase channels for this chat to prevent rate limit errors
    if (widget.chatGroupId != null) {
      _cleanupChatChannels(widget.chatGroupId!);
    }

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

  /// Clean up all Supabase channels for this chat
  void _cleanupChatChannels(String chatGroupId) {
    try {
      // Clean up all channels since we can't filter by topic
      final channels = SupabaseService.client.getChannels();
      for (final channel in channels) {
        SupabaseService.safeRemoveChannel(channel);
        debugPrint('🧹 Cleaned up channel');
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning up channels: $e');
    }
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

  /// Load mute status from Firestore and SharedPreferences
  Future<void> _loadMuteStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localMuted =
          prefs.getBool('chat_muted_${widget.chatGroupId ?? 'squad'}');

      // Try to load from Supabase for cross-device sync
      final currentUserId = _auth.currentUserId;
      if (currentUserId != null && widget.chatGroupId != null) {
        final userData = await SupabaseService.client
            .from('users')
            .select('user_groups')
            .eq('uid', currentUserId)
            .maybeSingle();

        if (userData != null) {
          final userGroups =
              List<Map<String, dynamic>>.from(userData['user_groups'] ?? []);
          final groupData = userGroups.firstWhere(
            (g) => g['id'] == widget.chatGroupId,
            orElse: () => <String, dynamic>{},
          );

          if (groupData.isNotEmpty &&
              groupData['notifications_enabled'] != null) {
            final supabaseMuted = !(groupData['notifications_enabled'] as bool);
            if (mounted) {
              setState(() {
                _isMuted = supabaseMuted;
              });
            }
            // Update local cache
            await prefs.setBool(
                'chat_muted_${widget.chatGroupId ?? 'squad'}', supabaseMuted);
            return;
          }
        }
      } else if (currentUserId != null && widget.chatType == ChatType.squad) {
        final userData = await SupabaseService.client
            .from('users')
            .select('squad_chat_muted')
            .eq('uid', currentUserId)
            .maybeSingle();

        if (userData != null && userData['squad_chat_muted'] != null) {
          final supabaseMuted = userData['squad_chat_muted'] as bool;
          if (mounted) {
            setState(() {
              _isMuted = supabaseMuted;
            });
          }
          await prefs.setBool(
              'chat_muted_${widget.chatGroupId ?? 'squad'}', supabaseMuted);
          return;
        }
      }

      // Fall back to local storage
      if (localMuted != null && mounted) {
        setState(() {
          _isMuted = localMuted;
        });
      }
    } catch (e) {
      debugPrint('Error loading mute status: $e');
    }
  }

  void _precacheBackgroundImage(
      BuildContext context, Map<String, dynamic> background) {
    final type = background['type'] ?? 'none';
    final value = background['value'] ?? '';

    if (type == 'image' && value.isNotEmpty && value != _cachedBackgroundUrl) {
      _cachedBackgroundUrl = value;
      _backgroundImageLoaded = false;

      precacheImage(NetworkImage(value), context).then((_) {
        if (mounted && _cachedBackgroundUrl == value) {
          setState(() {
            _backgroundImageLoaded = true;
          });
        }
      }).catchError((error) {
        debugPrint('Error precaching background image: $error');
        if (mounted) {
          setState(() {
            _backgroundImageLoaded =
                true; // Show anyway to avoid infinite loading
          });
        }
      });
    }
  }

  Future<void> _sendMessage(msg.Message? replyToMessage,
      [LobbyState? squadState]) async {
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

      // Determine chat group ID
      String? chatGroupId = widget.chatGroupId;
      if (chatGroupId == null && widget.chatType == ChatType.squad) {
        final squadAsync = ref.read(ln.lobbyNotifierProvider);
        chatGroupId = squadAsync.value?.selectedLobbyId;
      }
      if (chatGroupId == null) {
        // Cannot send message without chat group ID
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Cannot send message: no chat group selected')),
          );
        }
        return;
      }

      await ref.read(cn.chatNotifierProvider.notifier).sendMessage(
            ref,
            chatGroupId,
            _messageController.text,
            msg.MessageType.text,
            widget.chatType,
            replyTo: replyToMessage?.id,
          );

      // Message sent successfully
      _messageController.clear();
      // Clear reply after sending
      ref.read(cn.chatNotifierProvider.notifier).clearReplyToMessage();

      // Show success feedback with haptic
      HapticFeedback.lightImpact();
      // Add haptic feedback for successful send
      HapticFeedback.lightImpact();
      await _typingManager.onMessageSent(
        ref,
        chatGroupId: chatGroupId,
      );
      _scrollToBottom();
      await _checkFirstMessage();
    } catch (e) {
      debugPrint('ChatScreen: Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _sendMessage(replyToMessage, squadState),
            ),
          ),
        );
        // Haptic feedback for error
        HapticFeedback.mediumImpact();
      }
    }
  }

  Future<void> _handleCommand(String command) async {
    if (command.toLowerCase().startsWith('/peacock')) {
      _showPeacockModal(context);
    }
    // Add other commands here if needed
  }

  /// Handle lobby creation from chat
  /// Shows pinned games carousel and active lobbies
  Future<void> _handleLobbyCreation() async {
    if (widget.chatGroupId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No chat group ID available')),
        );
      }
      return;
    }

    try {
      await ChatLobbySheet.show(
        context,
        chatGroupId: widget.chatGroupId!,
        chatGroupName: _chatName,
      );
    } catch (e) {
      debugPrint('❌ Error showing lobby sheet: $e');
    }
  }

  /// Calculate number of active lobbies for badge
  int _getActiveLobbyCount() {
    final squadState = ref.read(ln.lobbyNotifierProvider).value;
    if (squadState == null || widget.chatGroupId == null) return 0;

    int count = 0;

    // Count private lobbies in this chat group
    squadState.gameLobbies.forEach((gameName, lobbies) {
      for (final lobby in lobbies) {
        if (lobby['chatGroupId'] == widget.chatGroupId &&
            lobby['isActive'] == true) {
          count++;
        }
      }
    });

    // Count public lobbies with group members
    squadState.gameLobbies.forEach((gameName, lobbies) {
      for (final lobby in lobbies) {
        if (lobby['isActive'] == true &&
            lobby['chatGroupId'] != widget.chatGroupId) {
          final spots = lobby['spots'] as List<String?>? ?? [];
          final hasGroupMember = spots.any(
              (uid) => uid != null && squadState.lobbyMemberUids.contains(uid));
          if (hasGroupMember) {
            count++;
          }
        }
      }
    });

    return count;
  }

  Future<void> _sendMedia() async {
    final chatGroupId = effectiveChatGroupId;
    if (chatGroupId == null) return;
    await _mediaHandler.sendMedia(ref,
        chatGroupId: chatGroupId, chatType: widget.chatType);
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
          // Media options row
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
                  icon: Icons.videocam,
                  label: 'Clip',
                  onTap: () {
                    Navigator.pop(context);
                    _sendClip();
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
                const Text('Lobby Up', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _handleLobbyCreation();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendClip() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video == null) return;

      // Haptic feedback on selection
      HapticFeedback.lightImpact();

      // Send clip message via ChatNotifier (processClip is called internally)
      await ref.read(cn.chatNotifierProvider.notifier).sendMessage(
            ref,
            widget.chatGroupId ?? '',
            'Clip', // Message text
            msg.MessageType.clip,
            widget.chatType,
            clipFilePath: video.path,
          );

      // Haptic feedback on send
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('ChatScreen: Failed to send clip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send clip: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        HapticFeedback.mediumImpact();
      }
    }
  }

  Widget _buildPlusMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor ?? Colors.white,
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

  /// Fetch display names for message senders
  void _fetchDisplayNamesForMessages(List<msg.Message> messages) {
    if (messages.isEmpty) return;

    // Extract unique sender IDs from messages
    final senderIds =
        messages.map((m) => m.senderId).whereType<String>().toSet().toList();

    // Trigger display name fetching in lobby notifier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(ln.lobbyNotifierProvider.notifier)
            .fetchDisplayNamesForUids(senderIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch Riverpod providers
    final squadStateData = ref.watch(ln.lobbyNotifierProvider);
    final chatStateData = ref.watch(cn.chatNotifierProvider);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          debugPrint('ChatScreen: Navigation popped successfully');
        }
      },
      child: squadStateData.when(
        data: (squadState) => chatStateData.when(
          data: (chatState) {
            // Monitor sync state changes for UI feedback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleSyncStateChanges(chatState);
            });

            return SafeArea(
              top: false,
              bottom: false,
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                extendBodyBehindAppBar: true,
                backgroundColor: Colors.transparent,
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
      ),
    );
  }

  /// Build lobby selector dropdown for multiple lobbies per chat group
  Widget _buildLobbySelector() {
    final currentLobbyId = ref.watch(currentLobbyIdProvider);

    // Cache the future to prevent repeated fetches on every rebuild
    _lobbiesFuture ??= _fetchLobbiesForChatGroup(widget.chatGroupId!);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _lobbiesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // Hide if no lobbies
        }

        final lobbies = snapshot.data!;
        if (lobbies.length == 1) {
          return const SizedBox.shrink(); // Hide if only one lobby
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.sports_esports,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Lobby:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: currentLobbyId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  items: lobbies.map((lobby) {
                    final gameFocus = lobby['game_focus'];
                    final gameName = gameFocus is String
                        ? gameFocus
                        : (gameFocus is Map
                            ? gameFocus['name'] ?? 'Unknown'
                            : 'Unknown');
                    return DropdownMenuItem<String>(
                      value: lobby['id'] as String,
                      child: Text(
                        '${lobby['name']} - $gameName',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (newLobbyId) {
                    if (newLobbyId != null && newLobbyId != currentLobbyId) {
                      // Update current lobby ID
                      ref
                          .read(lobbyNotifierProvider.notifier)
                          .setSelectedLobbyId(newLobbyId);

                      // Show feedback
                      if (mounted) {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Switched to lobby: ${lobbies.firstWhere((l) => l['id'] == newLobbyId)['name']}'),
                            duration: const Duration(seconds: 2),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Cache for lobby fetches to avoid repeated queries
  final Map<String, List<Map<String, dynamic>>> _lobbiesCache = {};
  DateTime? _lastLobbyFetch;

  /// Fetch all lobbies for the current chat group (with caching)
  Future<List<Map<String, dynamic>>> _fetchLobbiesForChatGroup(
      String chatGroupId) async {
    // Return cached result if fetched within last 30 seconds
    if (_lobbiesCache.containsKey(chatGroupId) &&
        _lastLobbyFetch != null &&
        DateTime.now().difference(_lastLobbyFetch!) <
            const Duration(seconds: 30)) {
      return _lobbiesCache[chatGroupId]!;
    }

    try {
      final response = await SupabaseService.client
          .from('lobbies')
          .select('id, name, game_focus, is_active')
          .eq('chat_group_id', chatGroupId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final lobbies = List<Map<String, dynamic>>.from(response);

      // Cache the result
      _lobbiesCache[chatGroupId] = lobbies;
      _lastLobbyFetch = DateTime.now();

      debugPrint('📊 Fetched ${lobbies.length} lobbies for group $chatGroupId');
      return lobbies;
    } catch (e) {
      debugPrint('❌ Error fetching lobbies for chat group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load lobbies: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return [];
    }
  }

  Widget _buildChatContent(BuildContext context, LobbyState squadStateData,
      cn_state.ChatState chatStateData) {
    // Use the passed chatStateData instead of Provider.of for Riverpod migration
    final chatState = chatStateData;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    final chatGroupId = effectiveChatGroupId;

    // If no chatGroupId, use default background
    if (chatGroupId == null) {
      return _buildChatContentWithBackground(
        context,
        squadStateData,
        chatState,
        keyboardHeight,
        isKeyboardVisible,
        {'type': 'color', 'value': '#0B0E14'},
      );
    }

    // StreamBuilder for dynamic background
    return StreamBuilder<Map<String, dynamic>>(
      stream: _backgroundService.getCurrentBackground(chatGroupId),
      builder: (context, snapshot) {
        final background =
            snapshot.data ?? {'type': 'color', 'value': '#0B0E14'};

        // Precache background image if it's a network image
        _precacheBackgroundImage(context, background);

        return _buildChatContentWithBackground(
          context,
          squadStateData,
          chatState,
          keyboardHeight,
          isKeyboardVisible,
          background,
        );
      },
    );
  }

  Widget _buildChatContentWithBackground(
    BuildContext context,
    LobbyState squadStateData,
    cn_state.ChatState chatState,
    double keyboardHeight,
    bool isKeyboardVisible,
    Map<String, dynamic> background,
  ) {
    // Calculate parallax offset based on scroll position
    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final parallaxOffset = scrollOffset * 0.2; // 20% parallax speed

    return Stack(
      children: [
        // Background layer with parallax (stays fixed, doesn't move with keyboard)
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, -parallaxOffset),
            child: _buildBackgroundDecoration(background),
          ),
        ),
        // Chat content with app bar positioned above scroll content
        Stack(
          children: [
            // Scrollable content that can scroll behind the app bar
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Dismiss keyboard when user starts scrolling
                if (notification is ScrollStartNotification) {
                  FocusScope.of(context).unfocus();
                }
                return false;
              },
              child: ref.watch(cn.chatNotifierProvider).when(
                    data: (chatStateData) {
                      final messages =
                          chatStateData.chatMessages[widget.chatGroupId] ?? [];

                      // Fetch display names for message senders
                      _fetchDisplayNamesForMessages(messages);

                      // Calculate input bar height dynamically
                      final hasReply = chatState.replyToMessage != null;
                      final inputBarHeight = hasReply ? 140.0 : 80.0;

                      return _uiManager.buildMessagesList(
                        ref: ref,
                        chatGroupId: widget.chatGroupId,
                        chatType: widget.chatType,
                        scrollController: _scrollControllerService,
                        messages: messages,
                        onMessageLongPress: () {}, // Will be implemented
                        onMessageTap: () {}, // Will be implemented
                        getSender: _getSender,
                        getTimestampMs: _getTimestampMs,
                        cleanText: _cleanText,
                        uidToDisplayName: squadStateData.memberDisplayNames,
                        // markAsDelivered removed - Supabase inserts are immediate
                        // Add padding to scroll under app bar and input bar
                        topPadding: (isUserGroup && widget.chatGroupId != null)
                            ? 100 +
                                MediaQuery.of(context).padding.top +
                                60 // App bar + lobby selector
                            : 100 +
                                MediaQuery.of(context)
                                    .padding
                                    .top, // Just app bar
                        bottomPadding: inputBarHeight +
                            (isKeyboardVisible
                                ? 0
                                : MediaQuery.of(context).viewPadding.bottom /
                                    2), // Allow scrolling under input bar
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Center(child: Text('Error loading messages: $error')),
                  ),
            ), // End NotificationListener
            // Input Bar positioned at bottom - moves up with keyboard
            Positioned(
              bottom: keyboardHeight,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply preview if exists
                      if (chatState.replyToMessage != null)
                        _uiManager.buildReplyPreview(
                          context,
                          chatState,
                          squadStateData,
                          widget.chatType,
                          () => ref
                              .read(cn.chatNotifierProvider.notifier)
                              .clearReplyToMessage(),
                        ),
                      // Input bar
                      Semantics(
                        label: 'Chat input bar',
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
                          // Pass actual members for @ mentions
                          availableMembers:
                              squadStateData.memberDisplayNames.values.toList(),
                          memberAvatars: _buildMemberAvatarMap(squadStateData),
                          // Pass background color for adaptive glass UI
                          backgroundColor: _getBackgroundColor(background),
                        ),
                      ),
                      // Add bottom padding for keyboard and iPhone home indicator
                      SizedBox(
                        height: isKeyboardVisible
                            ? 8.0
                            : 8.0 +
                                (MediaQuery.of(context).viewPadding.bottom / 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Lobby Selector positioned below app bar (for user groups)
            if (isUserGroup && widget.chatGroupId != null)
              Positioned(
                top: 100 + MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: _buildLobbySelector(),
              ),
            // App bar positioned at top of Stack
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: NeonChatAppBar(
                squadId: widget.chatGroupId ?? 'unknown',
                squadName: _chatName,
                avatarUrl: _chatImageUrl,
                backgroundColor: _getBackgroundColor(background),
                onBackPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/chat');
                  }
                },
                onGamepadPressed: isUserGroup ? _handleLobbyCreation : null,
                showGamepadBadge: isUserGroup && _getActiveLobbyCount() > 0,
                onCenterTapped: () async {
                  // Fetch actual member list from chat_groups table
                  List<Map<String, dynamic>> members = [];

                  try {
                    final chatGroupId = widget.chatGroupId;
                    if (chatGroupId != null) {
                      // Fetch chat group to get member UIDs
                      final groupResponse = await SupabaseService.client
                          .from('chat_groups')
                          .select('member_uids')
                          .eq('id', chatGroupId)
                          .maybeSingle();

                      if (groupResponse != null) {
                        final memberUids = List<String>.from(
                            groupResponse['member_uids'] ?? []);

                        // Fetch user profiles for all members
                        if (memberUids.isNotEmpty) {
                          final usersResponse = await SupabaseService.client
                              .from('users')
                              .select('uid, display_name, photo_url')
                              .inFilter('uid', memberUids);

                          members = (usersResponse as List)
                              .map((user) => {
                                    'uid': user['uid'] as String,
                                    'name': user['display_name'] as String? ??
                                        'Unknown',
                                    'avatarUrl': user['photo_url'] as String?,
                                    'isOnline': squadStateData
                                            .globalStatuses[user['uid']] !=
                                        null,
                                  })
                              .toList();
                        }
                      }
                    }
                  } catch (e) {
                    debugPrint('Error fetching members for chat info: $e');
                    // Fallback to using squadStateData
                    members = squadStateData.globalStatuses.entries
                        .map((e) => {
                              'uid': e.key,
                              'name':
                                  squadStateData.memberDisplayNames[e.key] ??
                                      'Unknown',
                              'avatarUrl':
                                  squadStateData.memberProfileImages?[e.key],
                              'isOnline': true,
                            })
                        .toList();
                  }

                  // Open ChatInfoScreen with ripple overlay animation
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    _RipplePageRoute(
                      page: ChatInfoScreen(
                        squadId: widget.chatGroupId ?? 'unknown',
                        squadName: _chatName,
                        avatarUrl: _chatImageUrl,
                        chatType: widget.chatType,
                        members: members,
                      ),
                    ),
                  );
                },
              ),
            ),
          ], // End inner Stack children
        ), // End inner Stack
      ], // End outer Stack children
    ); // End outer Stack
  }

  /// Helper to extract the dominant background color for adaptive UI
  Color _getBackgroundColor(Map<String, dynamic> background) {
    final type = background['type'] ?? 'none';
    final value = background['value'] ?? '';

    switch (type) {
      case 'color':
      case 'solid':
        if (value.isEmpty || !value.startsWith('#')) {
          return const Color(0xFF0B0E14); // Default dark
        }
        try {
          return Color(
            int.parse(value.substring(1), radix: 16) + 0xFF000000,
          );
        } catch (e) {
          return const Color(0xFF0B0E14);
        }

      case 'gradient':
        // Extract first color from gradient
        final parts = value.split(':');
        if (parts.length >= 3) {
          final colorStrings = parts[2].split(',');
          if (colorStrings.isNotEmpty) {
            try {
              return Color(
                  int.parse(colorStrings[0].replaceAll('0x', ''), radix: 16));
            } catch (e) {
              return const Color(0xFF0B0E14);
            }
          }
        }
        return const Color(0xFF0B0E14);

      case 'preset':
        final presetValue = BackgroundService.presets[value];
        if (presetValue != null && presetValue.startsWith('#')) {
          try {
            return Color(
              int.parse(presetValue.substring(1), radix: 16) + 0xFF000000,
            );
          } catch (e) {
            return const Color(0xFF0B0E14);
          }
        }
        return const Color(0xFF0B0E14);

      case 'image':
      case 'gameTheme':
        // For image/game theme backgrounds, assume mixed content - use semi-dark
        return const Color(0xFF404040);

      default:
        return const Color(0xFF0B0E14);
    }
  }

  Widget _buildBackgroundDecoration(Map<String, dynamic> background) {
    final type = background['type'] ?? 'none';
    final value = background['value'] ?? '';

    switch (type) {
      case 'color':
      case 'solid':
        // Solid color background
        if (value.isEmpty || !value.startsWith('#')) {
          return Container(color: const Color(0xFF0B0E14)); // Default
        }
        try {
          final color = Color(
            int.parse(value.substring(1), radix: 16) + 0xFF000000,
          );
          return Container(color: color);
        } catch (e) {
          return Container(color: const Color(0xFF0B0E14));
        }

      case 'gradient':
        // Parse gradient string: gradient:linear:0xFF00F5FF,0xFFFF00FF
        return _buildGradientBackground(value);

      case 'image':
        // Network image - full brightness for custom backgrounds
        if (value.isEmpty) {
          return Container(color: const Color(0xFF0B0E14));
        }
        // Show placeholder while loading, then fade in the image
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _backgroundImageLoaded && _cachedBackgroundUrl == value
              ? Container(
                  key: ValueKey(value),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(value),
                      fit: BoxFit.cover,
                      opacity: 1.0,
                    ),
                  ),
                )
              : Container(
                  key: const ValueKey('placeholder'),
                  color: const Color(0xFF0B0E14),
                ),
        );

      case 'preset':
        // Handle preset backgrounds
        final presetValue = BackgroundService.presets[value];
        if (presetValue == null) {
          return Container(color: const Color(0xFF0B0E14));
        }

        // Check if preset is a color
        if (presetValue.startsWith('#')) {
          try {
            final color = Color(
              int.parse(presetValue.substring(1), radix: 16) + 0xFF000000,
            );
            return Container(color: color);
          } catch (e) {
            return Container(color: const Color(0xFF0B0E14));
          }
        }

        // Check if preset is a gradient
        if (presetValue.startsWith('gradient:')) {
          return _buildGradientBackground(presetValue);
        }

        // Check if preset is an asset image
        if (presetValue.startsWith('assets/')) {
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(presetValue),
                fit: BoxFit.cover,
                opacity: 0.3,
              ),
            ),
          );
        }

        // Network image
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(presetValue),
              fit: BoxFit.cover,
              opacity: 0.3,
            ),
          ),
        );

      case 'gameTheme':
        // Use current game theme colors as gradient
        // You can integrate with GameThemeController here
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.3),
                Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              ],
            ),
          ),
        );

      default:
        // Default dark background
        return Container(color: const Color(0xFF0B0E14));
    }
  }

  Widget _buildGradientBackground(String gradientString) {
    try {
      // Parse gradient string format: gradient:linear:0xFF00F5FF,0xFFFF00FF
      // or gradient:radial:0xFFFF4500,0xFF8B0000
      final parts = gradientString.split(':');
      if (parts.length < 3) {
        return Container(color: const Color(0xFF0B0E14));
      }

      final gradientType = parts[1]; // linear or radial
      final colorStrings = parts[2].split(',');

      if (colorStrings.length < 2) {
        return Container(color: const Color(0xFF0B0E14));
      }

      final colors = colorStrings.map((colorStr) {
        try {
          return Color(int.parse(colorStr.replaceAll('0x', ''), radix: 16));
        } catch (e) {
          return const Color(0xFF0B0E14);
        }
      }).toList();

      if (gradientType == 'radial') {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: colors,
              center: Alignment.center,
              radius: 1.0,
            ),
          ),
        );
      } else {
        // Default to linear
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error parsing gradient: $e');
      return Container(color: const Color(0xFF0B0E14));
    }
  }
}

/// Custom page route for ripple overlay animation
class _RipplePageRoute extends PageRouteBuilder {
  final Widget page;

  _RipplePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          opaque: false, // Makes the route transparent
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Ripple scale animation with fade
            final scaleAnimation = Tween<double>(
              begin: 0.7,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            ));

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
        );
}
