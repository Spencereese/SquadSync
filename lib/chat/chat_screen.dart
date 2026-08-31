import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async'; // Added for StreamSubscription
import 'dialogs/full_screen_lobby_creation.dart';

import '../utils.dart';
import '../services/background_service.dart';

import 'chat_input_bar.dart';
import 'peacock_modal.dart';
import 'poll_creation_dialog.dart';
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
import '../presentation/notifiers/message_notifier.dart';
import '../presentation/notifiers/notification_notifier.dart';
import '../core/chat_messages.dart';

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

  bool _isMuted = false;
  double _previousKeyboardHeight = 0.0;
  bool? _previousSyncState;

  // Debounce guard for chat info navigation
  DateTime? _lastChatInfoNavigation;
  static const _chatInfoDebounceMs = 500;

  // Cache for lobbies future to prevent repeated fetches
  Future<List<Map<String, dynamic>>>? _lobbiesFuture;

  // Image preview state
  XFile? _selectedImage;
  bool _showImagePreview = false;

  // Guard to prevent repeated lobby queries in didChangeDependencies
  bool _hasQueriedLobby = false;

  // CRITICAL: Guard to prevent repeated chat initialization
  // didChangeDependencies() runs on EVERY dependency change (MediaQuery, keyboard, etc.)
  bool _hasInitializedChat = false;

  /// Captured while [ref] is valid. Dispose must not call [ref] (Riverpod 2.x).
  NotificationNotifier? _notificationNotifier;
  String? _registeredActiveChatGroupId;
  String? _typingListenerChatGroupId;
  bool _initializationServiceCompleted = false;
  ChatInitBail _initializationServiceBail = ChatInitBail.none;
  int _initializationServiceGeneration = 0;
  int _initializationHardFailureRetries = 0;
  int _channelRateLimitRetries = 0;

  // CRITICAL: Cached state to prevent build() from watching providers
  // This stops disposal loops from keyboard/focus/MediaQuery changes
  LobbyState? _cachedSquadState;
  cs.ChatState? _cachedChatState;
  MessageState? _cachedMessageState;

  bool get isUserGroup => widget.chatType == ChatType.userGroup;
  bool get isDM => widget.chatType == ChatType.dm;

  String? get effectiveChatGroupId {
    return resolveActiveChatGroupId(
      widgetChatGroupId: widget.chatGroupId,
      isSquad: widget.chatType == ChatType.squad,
      selectedLobbyId: widget.chatType == ChatType.squad
          ? (_cachedSquadState?.selectedLobbyId ?? _registeredActiveChatGroupId)
          : null,
    );
  }

  /// Widget id, else the registered squad/lobby thread. Never `''`.
  String? get threadChatGroupId {
    final registered = _registeredActiveChatGroupId;
    if (registered != null && registered.isNotEmpty) return registered;
    return effectiveChatGroupId;
  }

  @visibleForTesting
  String? get debugRegisteredActiveChatGroupId => _registeredActiveChatGroupId;

  /// Register the open thread for badge skip. No-op until the id is non-null.
  /// First non-null id also starts initializeChat / loadUserGroups.
  void _syncActiveChatThread({String? selectedLobbyId}) {
    final notifier = _notificationNotifier;
    if (notifier == null) return;
    final id = resolveActiveChatGroupId(
      widgetChatGroupId: widget.chatGroupId,
      isSquad: widget.chatType == ChatType.squad,
      selectedLobbyId: selectedLobbyId ??
          (widget.chatType == ChatType.squad
              ? _cachedSquadState?.selectedLobbyId
              : null),
    );
    final isNewId = id != null && id != _registeredActiveChatGroupId;
    if (isNewId) {
      final previousId = _registeredActiveChatGroupId;
      if (shouldCleanupPreviousThreadChannels(
        previousId: previousId,
        nextId: id,
      )) {
        _cleanupChatChannels(threadId: previousId);
      }
      _registeredActiveChatGroupId = id;
      _initializationServiceGeneration++;
      scheduleProviderWriteAfterBuild(() {
        if (!mounted) return;
        if (id != _registeredActiveChatGroupId) return;
        _notificationNotifier?.setActiveChatGroup(id);
      });
      _bindTypingListener(id);
      if (shouldStartChatInitialization(
        alreadyInitialized: _hasInitializedChat,
        nextThreadId: id,
      )) {
        _hasInitializedChat = true;
        _resetInitializationServiceFlags();
        _scheduleChatStart(id, _initializationServiceGeneration);
      } else if (shouldRefreshChatInitializationOnNewThread(
        alreadyInitialized: _hasInitializedChat,
        isNewId: true,
      )) {
        _resetInitializationServiceFlags();
        _scheduleChatStart(id, _initializationServiceGeneration);
      }
    }
    _retryInitializationServiceIfNeeded();
  }

  void _resetInitializationServiceFlags({bool resetRateLimitRetries = true}) {
    _initializationServiceCompleted = false;
    _initializationServiceBail = ChatInitBail.none;
    _initializationHardFailureRetries = 0;
    if (resetRateLimitRetries) {
      _channelRateLimitRetries = 0;
    }
  }

  void _bindTypingListener(String chatGroupId) {
    if (_typingListenerChatGroupId == chatGroupId) return;
    _typingListenerChatGroupId = chatGroupId;
    _typingManager.initializeTypingListener(
      ref,
      chatGroupId: chatGroupId,
      chatType: widget.chatType,
    );
  }

  void _scheduleChatStart(String chatGroupId, int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (generation != _initializationServiceGeneration ||
          chatGroupId != _registeredActiveChatGroupId) {
        return;
      }
      _startNotifierChat(chatGroupId, generation);
      _runInitializationService(chatGroupId, generation);
    });
  }

  void _startNotifierChat(String chatGroupId, int generation) {
    if (generation != _initializationServiceGeneration ||
        chatGroupId != _registeredActiveChatGroupId) {
      return;
    }
    ref.read(cn.chatNotifierProvider.notifier).loadUserGroups();
    ref
        .read(cn.chatNotifierProvider.notifier)
        .initializeChat(chatGroupId, widget.chatType)
        .then((_) {
      if (!mounted ||
          generation != _initializationServiceGeneration ||
          chatGroupId != _registeredActiveChatGroupId) {
        return;
      }
      _channelRateLimitRetries = 0;
    }).catchError((error) {
      if (!mounted ||
          generation != _initializationServiceGeneration ||
          chatGroupId != _registeredActiveChatGroupId) {
        return;
      }
      String errorMsg = error.toString();
      if (errorMsg.contains('ChannelRateLimitReached')) {
        errorMsg = rateLimitRetrySnackMessage(_channelRateLimitRetries);
        SupabaseService.dispose();
        if (shouldScheduleRateLimitRetry(_channelRateLimitRetries)) {
          _channelRateLimitRetries++;
          Future.delayed(const Duration(seconds: 1), () {
            if (!shouldContinueDelayedChatReinit(
              isMounted: mounted,
              scheduledId: chatGroupId,
              scheduledGeneration: generation,
              currentRegisteredId: _registeredActiveChatGroupId,
              currentGeneration: _initializationServiceGeneration,
            )) {
              return;
            }
            _resetInitializationServiceFlags(
              resetRateLimitRetries:
                  shouldZeroRateLimitRetries(delayedReplay: true),
            );
            _scheduleChatStart(
              chatGroupId,
              _initializationServiceGeneration,
            );
          });
        }
      } else if (errorMsg.contains('channelError')) {
        errorMsg = 'Connection issue. Chat will work with limited features.';
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
    });
  }

  Future<void> _runInitializationService(
    String chatGroupId,
    int generation,
  ) async {
    if (!mounted) return;
    if (!shouldRunInitializationService(
      requestedId: chatGroupId,
      requestedGeneration: generation,
      currentRegisteredId: _registeredActiveChatGroupId,
      currentGeneration: _initializationServiceGeneration,
      alreadyCompleted: _initializationServiceCompleted,
    )) {
      return;
    }
    try {
      final ran = await _initializationService.initializeChat(
        context: context,
        ref: ref,
        chatGroupId: chatGroupId,
        chatGroupName: widget.chatGroupName,
        chatType: widget.chatType,
        setChatName: (name) {
          if (!shouldCommitInitializationCompletion(
            finishingId: chatGroupId,
            finishingGeneration: generation,
            currentRegisteredId: _registeredActiveChatGroupId,
            currentGeneration: _initializationServiceGeneration,
          )) {
            return;
          }
          if (mounted) setState(() => _chatName = name);
          _uiManager.chatName = name;
        },
        setChatImageUrl: (url) {
          if (!shouldCommitInitializationCompletion(
            finishingId: chatGroupId,
            finishingGeneration: generation,
            currentRegisteredId: _registeredActiveChatGroupId,
            currentGeneration: _initializationServiceGeneration,
          )) {
            return;
          }
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
        squadState: _cachedSquadState,
      );
      if (!mounted) return;
      if (!shouldCommitInitializationCompletion(
        finishingId: chatGroupId,
        finishingGeneration: generation,
        currentRegisteredId: _registeredActiveChatGroupId,
        currentGeneration: _initializationServiceGeneration,
      )) {
        return;
      }
      if (ran) {
        _initializationServiceCompleted = true;
        _initializationServiceBail = ChatInitBail.none;
        _initializationHardFailureRetries = 0;
      } else {
        _initializationServiceBail = ChatInitBail.nullSquad;
      }
    } catch (e) {
      debugPrint('ChatInitializationService failed: $e');
      if (!shouldCommitInitializationCompletion(
        finishingId: chatGroupId,
        finishingGeneration: generation,
        currentRegisteredId: _registeredActiveChatGroupId,
        currentGeneration: _initializationServiceGeneration,
      )) {
        return;
      }
      _initializationServiceBail = ChatInitBail.hardFailure;
      if (shouldShowInitFailureSnackBar(_initializationHardFailureRetries) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not finish opening chat')),
        );
      }
      final shouldRetry = shouldRetryChatInitializationService(
        serviceCompleted: false,
        bail: ChatInitBail.hardFailure,
        squadStateAvailable: _cachedSquadState != null,
        hardFailureRetries: _initializationHardFailureRetries,
      );
      _initializationHardFailureRetries++;
      if (shouldRetry) {
        final id = threadChatGroupId;
        if (id != null) {
          final retryGeneration = _initializationServiceGeneration;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _runInitializationService(id, retryGeneration);
          });
        }
      }
    }
  }

  void _retryInitializationServiceIfNeeded() {
    if (!shouldRetryChatInitializationService(
      serviceCompleted: _initializationServiceCompleted,
      bail: _initializationServiceBail,
      squadStateAvailable: _cachedSquadState != null,
      hardFailureRetries: _initializationHardFailureRetries,
    )) {
      return;
    }
    final id = threadChatGroupId;
    if (id == null) return;
    if (_initializationServiceBail == ChatInitBail.nullSquad) {
      _initializationServiceBail = ChatInitBail.none;
    }
    final generation = _initializationServiceGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runInitializationService(id, generation);
    });
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

    // CRITICAL: Clear message cache on init to force processing
    _uiManager.clearMessageCache();
    debugPrint('🧹 Cleared message cache on ChatScreen init');

    // Capture even when chatGroupId starts null so dispose can still clear.
    _notificationNotifier = ref.read(notificationNotifierProvider.notifier);

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

    // Load chat image URL early for user groups to prevent blank avatar on first load
    if (widget.chatType == ChatType.userGroup && widget.chatGroupId != null) {
      _loadChatImageUrl();
    }

    // Load mute status from local storage first
    _loadMuteStatus();

    // Initialize UI manager with current state AFTER setting the correct chat name
    _uiManager.initialize(
      initialChatName: _chatName,
      initialChatImageUrl: _chatImageUrl,
      initialIsMuted: _isMuted,
    );

    _syncActiveChatThread();

    // CRITICAL FIX: Use ref.listen() instead of ref.watch() in build()
    // This prevents disposal cascades from keyboard/MediaQuery changes
    ref.listenManual(
      ln.lobbyNotifierProvider.select((value) => value.valueOrNull),
      (previous, next) {
        if (mounted && next != null) {
          setState(() => _cachedSquadState = next);
          _syncActiveChatThread(selectedLobbyId: next.selectedLobbyId);
        }
      },
      fireImmediately: true,
    );

    ref.listenManual(
      cn.chatNotifierProvider.select((value) => value.valueOrNull),
      (previous, next) {
        if (mounted && next != null) {
          setState(() => _cachedChatState = next);
        }
      },
      fireImmediately: true,
    );

    ref.listenManual(
      messageNotifierProvider.select((value) => value.valueOrNull),
      (previous, next) {
        if (mounted && next != null) {
          setState(() => _cachedMessageState = next);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set squad ID for user group chats by querying lobby table
    if (widget.chatType == ChatType.userGroup &&
        widget.chatGroupId != null &&
        !_hasQueriedLobby) {
      _hasQueriedLobby = true; // Guard to prevent repeated queries

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

    // ChatNotifier / ChatInitializationService start from _syncActiveChatThread
    // once threadChatGroupId is non-null (late squad lobby id included).

    // Initialize scroll controller with callbacks
    _scrollControllerService.initialize(
      onScrollChanged: () => mounted ? setState(() {}) : null,
      onLoadMoreMessages: _loadMoreMessages,
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
    final threadId = _registeredActiveChatGroupId ?? widget.chatGroupId;
    _notificationNotifier?.setActiveChatGroup(null);
    _notificationNotifier = null;
    _registeredActiveChatGroupId = null;
    _cleanupChatChannels(threadId: threadId);

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

  /// Removes chat/thread realtime channels when topic is readable.
  /// Falls back to removing every channel if topics are unavailable.
  void _cleanupChatChannels({String? threadId}) {
    try {
      final channels = SupabaseService.client.getChannels();
      final scoped = <RealtimeChannel>[];
      var readable = 0;
      var unreadable = 0;
      for (final channel in channels) {
        final topic = _realtimeChannelTopic(channel);
        if (topic == null) {
          unreadable++;
          continue;
        }
        readable++;
        if (isChatThreadChannelTopic(topic, threadId)) {
          scoped.add(channel);
        }
      }
      final mode = channelCleanupMode(
        readableTopicCount: readable,
        unreadableTopicCount: unreadable,
      );
      final toRemove =
          mode == ChannelCleanupMode.nukeAll ? channels : scoped;
      if (mode == ChannelCleanupMode.nukeAll) {
        debugPrint(
            '🧹 Channel topics unavailable; removing all ${channels.length} channels');
      } else {
        debugPrint(
            '🧹 Removing ${toRemove.length} chat channels for $threadId (skipped $unreadable unread)');
      }
      for (final channel in toRemove) {
        SupabaseService.safeRemoveChannel(channel);
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning up channels: $e');
    }
  }

  /// realtime_client marks [topic] `@internal`; it is the only handle we have.
  String? _realtimeChannelTopic(RealtimeChannel channel) {
    try {
      // ignore: invalid_use_of_internal_member
      final topic = channel.topic;
      if (topic.isNotEmpty) return topic;
    } catch (e) {
      debugPrint('Channel topic unread: $e');
    }
    return null;
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

    _previousSyncState = chatState.isSyncing;
  }

  Future<void> _loadMoreMessages() async {
    await _scrollControllerService.loadMoreMessages(
      chatGroupId: threadChatGroupId,
      onStateChanged: () => mounted ? setState(() {}) : null,
    );
  }

  void _scrollToBottom() {
    _scrollControllerService.scrollToBottom();
  }

  /// Load mute status from Firestore and SharedPreferences
  Future<void> _loadChatImageUrl() async {
    try {
      if (widget.chatGroupId == null) return;

      final data = await SupabaseService.client
          .from('chat_groups')
          .select('avatar_url')
          .eq('id', widget.chatGroupId!)
          .maybeSingle();

      if (data != null && data['avatar_url'] != null && mounted) {
        setState(() {
          _chatImageUrl = data['avatar_url'] as String;
          _uiManager.chatImageUrl = _chatImageUrl;
        });
      }
    } catch (e) {
      debugPrint('Error loading chat image URL: $e');
    }
  }

  Future<void> _loadMuteStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muteKey = 'chat_muted_${threadChatGroupId ?? 'squad'}';
      final localMuted = prefs.getBool(muteKey);

      // Try to load from Supabase for cross-device sync
      final currentUserId = _auth.currentUserId;
      final threadId = threadChatGroupId;
      if (currentUserId != null &&
          threadId != null &&
          widget.chatType != ChatType.squad) {
        final userData = await SupabaseService.client
            .from('users')
            .select('user_groups')
            .eq('uid', currentUserId)
            .maybeSingle();

        if (userData != null) {
          final userGroups =
              List<Map<String, dynamic>>.from(userData['user_groups'] ?? []);
          final groupData = userGroups.firstWhere(
            (g) => g['id'] == threadId,
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
            await prefs.setBool(muteKey, supabaseMuted);
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
          await prefs.setBool(muteKey, supabaseMuted);
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
    // Add logging to debug background issues
    final type = background['type'];
    final value = background['value'];
    debugPrint('🎨 Background loaded: type=$type, value=$value');

    // Precache network images to prevent loading delays
    if (type == 'image' && value != null && value.isNotEmpty) {
      try {
        precacheImage(NetworkImage(value), context).catchError((error) {
          debugPrint('❌ Failed to precache background image: $error');
          return null;
        });
      } catch (e) {
        debugPrint('❌ Error precaching background: $e');
      }
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

      final chatGroupId = threadChatGroupId;
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
  /// Opens full-screen lobby creation directly
  Future<void> _handleLobbyCreation() async {
    final chatGroupId = threadChatGroupId;
    if (chatGroupId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No chat group ID available')),
        );
      }
      return;
    }

    try {
      HapticFeedback.lightImpact();
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              FullScreenLobbyCreation(chatGroupId: chatGroupId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          opaque: false,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error showing lobby creation: $e');
    }
  }

  /// Calculate number of active lobbies for badge
  int _getActiveLobbyCount() {
    final squadState = ref.read(ln.lobbyNotifierProvider).value;
    final chatGroupId = threadChatGroupId;
    if (squadState == null || chatGroupId == null) return 0;

    int count = 0;

    // Count private lobbies in this chat group
    squadState.gameLobbies.forEach((gameName, lobbies) {
      for (final lobby in lobbies) {
        if (lobby['chatGroupId'] == chatGroupId &&
            lobby['isActive'] == true) {
          count++;
        }
      }
    });

    // Count public lobbies with group members
    squadState.gameLobbies.forEach((gameName, lobbies) {
      for (final lobby in lobbies) {
        if (lobby['isActive'] == true &&
            lobby['chatGroupId'] != chatGroupId) {
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
    // Pick media and show preview
    final media = await _mediaHandler.pickMedia();
    if (media != null) {
      setState(() {
        _selectedImage = media;
        _showImagePreview = true;
      });
    }
  }

  Future<void> _confirmSendImage() async {
    if (_selectedImage == null) return;

    final chatGroupId = threadChatGroupId;
    if (chatGroupId == null) return;

    final messageText = _messageController.text;
    _messageController.clear();

    setState(() {
      _showImagePreview = false;
    });

    await _mediaHandler.sendMedia(
      ref,
      chatGroupId: chatGroupId,
      chatType: widget.chatType,
      media: _selectedImage!,
      messageText: messageText.isNotEmpty ? messageText : null,
    );

    setState(() {
      _selectedImage = null;
    });
  }

  void _cancelImagePreview() {
    setState(() {
      _selectedImage = null;
      _showImagePreview = false;
    });
  }

  Future<void> _startRecording() async {
    await _mediaHandler.startRecording(ref);
    _animationController.repeat();
  }

  Future<void> _stopRecording() async {
    await _mediaHandler.stopRecording(ref,
        chatGroupId: threadChatGroupId, chatType: widget.chatType);
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
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Attach',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                Divider(
                  color: Colors.white.withOpacity(0.2),
                  height: 1,
                ),

                const SizedBox(height: 8),

                // Menu options with glass effect
                _buildGlassMenuItem(
                  context: context,
                  icon: Icons.photo_library,
                  iconColor: Colors.white,
                  title: 'Photos',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    _sendMedia();
                  },
                ),
                _buildGlassMenuItem(
                  context: context,
                  icon: Icons.camera_alt,
                  iconColor: Colors.blue,
                  title: 'Camera',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    _sendMedia();
                  },
                ),
                _buildGlassMenuItem(
                  context: context,
                  icon: Icons.videocam,
                  iconColor: Colors.red,
                  title: 'Clip',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    _sendClip();
                  },
                ),
                _buildGlassMenuItem(
                  context: context,
                  icon: Icons.poll,
                  iconColor: Colors.green,
                  title: 'Create Poll',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    PollCreationDialog.show(context,
                        chatGroupId: threadChatGroupId,
                        chatType: widget.chatType);
                  },
                ),
                _buildGlassMenuItem(
                  context: context,
                  icon: Icons.flash_on,
                  iconColor: Colors.cyanAccent,
                  title: 'Lobby Up',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    _handleLobbyCreation();
                  },
                ),

                SizedBox(
                  height: 20 + MediaQuery.viewPaddingOf(context).bottom,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendClip() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video == null) return;

      final chatGroupId = threadChatGroupId;
      if (chatGroupId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Cannot send clip: no chat group selected')),
          );
        }
        return;
      }

      // Haptic feedback on selection
      HapticFeedback.lightImpact();

      // Send clip message via ChatNotifier (processClip is called internally)
      await ref.read(cn.chatNotifierProvider.notifier).sendMessage(
            ref,
            chatGroupId,
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
    // CRITICAL FIX: Use cached state from ref.listen() instead of ref.watch()
    // This prevents build() from triggering disposal cascades
    // State updates happen via setState() in listeners only
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          debugPrint('ChatScreen: Navigation popped successfully');
        }
      },
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            body: (_cachedSquadState != null && _cachedChatState != null)
                ? _buildChatContent(
                    context, _cachedSquadState!, _cachedChatState!)
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
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
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.sports_esports,
                size: 18,
                color: Colors.white,
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
                            backgroundColor: Colors.grey[800],
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
    final chatGroupId = threadChatGroupId;

    // Auto-scroll when keyboard appears
    if (keyboardHeight > 0 && _previousKeyboardHeight == 0) {
      // Keyboard just appeared, scroll to bottom after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0.0, // Scroll to bottom (reversed list)
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _previousKeyboardHeight = keyboardHeight;

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
        // Enhanced logging for debugging
        if (snapshot.hasError) {
          debugPrint('❌ Background stream error: ${snapshot.error}');
        }
        if (snapshot.hasData) {
          debugPrint('✅ Background stream data: ${snapshot.data}');
        } else {
          debugPrint(
              '⚠️ Background stream: no data yet (connectionState: ${snapshot.connectionState})');
        }

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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // Dismiss keyboard when tapping anywhere
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        children: [
          // Background layer with parallax (stays fixed, doesn't move with keyboard)
          MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, -parallaxOffset),
                child: _buildBackgroundDecoration(background),
              ),
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
                child: Builder(
                      builder: (context) {
                        final messages = messagesForOpenThread(
                          threadId: threadChatGroupId,
                          ownerMessages:
                              _cachedMessageState?.messages ?? const {},
                          fallback: chatState.chatMessages,
                        );

                        debugPrint(
                            '📬 ChatScreen: Got ${messages.length} messages from MessageNotifier for group $threadChatGroupId');

                        // Fetch display names for message senders
                        _fetchDisplayNamesForMessages(messages);

                        // Calculate input bar height dynamically
                        final hasReply = chatState.replyToMessage != null;
                        final inputBarHeight = hasReply ? 140.0 : 80.0;

                        return _uiManager.buildMessagesList(
                          ref: ref,
                          chatGroupId: threadChatGroupId,
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
                          topPadding:
                              (isUserGroup && widget.chatGroupId != null)
                                  ? 100 +
                                      MediaQuery.of(context).padding.top +
                                      60 // App bar + lobby selector
                                  : 100 +
                                      MediaQuery.of(context)
                                          .padding
                                          .top, // Just app bar
                          bottomPadding: inputBarHeight +
                              keyboardHeight +
                              (isKeyboardVisible
                                  ? 0
                                  : MediaQuery.viewPaddingOf(context).bottom),
                        );
                      },
                    ),
              ), // End NotificationListener
              // Input Bar positioned at bottom - moves up with keyboard
              AnimatedPositioned(
                duration: Duration.zero,
                curve: Curves.easeOut,
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
                        // Image preview
                        if (_showImagePreview && _selectedImage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey[700]!,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Image thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_selectedImage!.path),
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // File info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Image selected',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Add caption or send',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Cancel button
                                IconButton(
                                  icon: Icon(Icons.close, color: Colors.white),
                                  onPressed: _cancelImagePreview,
                                ),
                              ],
                            ),
                          ),
                        // Input bar
                        Semantics(
                          label: 'Chat input bar',
                          child: ChatInputBar(
                            controller: _messageController,
                            focusNode: _inputFocusNode,
                            isRecording: chatState.isRecording,
                            isUploading: chatState.isUploading,
                            onSend: _showImagePreview
                                ? _confirmSendImage
                                : () => _sendMessage(
                                    chatState.replyToMessage, squadStateData),
                            onMedia: _sendMedia,
                            onRecordStart: _startRecording,
                            onRecordStop: _stopRecording,
                            onPlusMenu: () => _showPlusMenu(context),
                            onTextChanged: (value) {
                              _typingManager.onTextChanged(
                                value,
                                ref,
                                chatGroupId: threadChatGroupId,
                              );
                            },
                            quickReactionEmoji: chatState.quickReactionEmoji,
                            hintText: _showImagePreview
                                ? 'Caption'
                                : (chatState.replyToMessage != null
                                    ? 'Reply'
                                    : 'Message'),
                            hasAttachment: _showImagePreview,
                            // Pass actual members for @ mentions
                            availableMembers: squadStateData
                                .memberDisplayNames.values
                                .toList(),
                            memberAvatars:
                                _buildMemberAvatarMap(squadStateData),
                            // Pass background color for adaptive glass UI
                            backgroundColor: _getBackgroundColor(background),
                          ),
                        ),
                        // Home indicator / Dynamic Island bottom inset when the
                        // keyboard is hidden. Keyboard already replaces that inset.
                        SizedBox(
                          height: isKeyboardVisible
                              ? 8.0
                              : 8.0 +
                                  MediaQuery.viewPaddingOf(context).bottom,
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
                  squadId: threadChatGroupId ?? 'unknown',
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
                    // Debounce rapid taps to prevent multiple navigations
                    final now = DateTime.now();
                    if (_lastChatInfoNavigation != null) {
                      final timeSinceLastNav = now
                          .difference(_lastChatInfoNavigation!)
                          .inMilliseconds;
                      if (timeSinceLastNav < _chatInfoDebounceMs) {
                        debugPrint(
                            'ChatScreen: Debouncing rapid chat info tap (${timeSinceLastNav}ms ago)');
                        return;
                      }
                    }
                    _lastChatInfoNavigation = now;

                    // Fetch actual member list from chat_groups table
                    List<Map<String, dynamic>> members = [];

                    try {
                      final chatGroupId = threadChatGroupId;
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
                          squadId: threadChatGroupId ?? 'unknown',
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
      ), // End outer Stack
    ); // End GestureDetector
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
          debugPrint('⚠️ Image background has empty value');
          return Container(color: const Color(0xFF0B0E14));
        }
        debugPrint('🖼️ Loading image background: $value');
        // CachedNetworkImage loads instantly from cache on subsequent opens
        return CachedNetworkImage(
          imageUrl: value,
          fit: BoxFit.cover,
          maxWidthDiskCache: 1080, // Optimize memory usage
          maxHeightDiskCache: 1920,
          fadeInDuration:
              Duration.zero, // No fade animation for instant display
          fadeOutDuration: Duration.zero,
          imageBuilder: (context, imageProvider) {
            debugPrint('✅ Background image loaded successfully');
            return Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
          placeholder: (context, url) {
            return Container(color: const Color(0xFF0B0E14));
          },
          errorWidget: (context, url, error) {
            debugPrint('❌ Failed to load background image: $error');
            return Container(
              color: const Color(0xFF0B0E14),
              child: Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white24,
                  size: 48,
                ),
              ),
            );
          },
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
                Colors.white.withOpacity(0.05),
                Colors.grey.withOpacity(0.05),
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
