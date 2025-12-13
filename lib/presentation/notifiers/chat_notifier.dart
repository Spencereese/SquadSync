import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/domain/entities/chat_state.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/services/error_handling_service.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service_supabase.dart';
import 'message_notifier.dart';
import 'media_notifier.dart';
import 'offline_first_mixin.dart';
import 'game_notifier.dart';
import 'lobby_notifier.dart';

/// ChatNotifier - Coordinator for chat functionality
/// Delegates to MessageNotifier and MediaNotifier for specific operations
/// Handles group management, presence tracking, and UI state coordination
/// NOW WITH OFFLINE-FIRST SUPPORT via OfflineFirstMixin
/// Uses AsyncNotifier (not AutoDispose) to persist state across navigation
class ChatNotifier extends AsyncNotifier<ChatState> with OfflineFirstMixin {
  // Use getters to avoid late initialization errors when build() is called multiple times
  ChatRepository get _repository => ref.read(chatRepositoryProvider);
  ErrorHandlingService get _errorHandler =>
      ref.read(errorHandlingServiceProvider);
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  // Presence tracking
  RealtimeChannel? _presenceChannel;
  String? _currentChatGroupId;
  ChatType? _currentChatType;

  @override
  Future<ChatState> build() async {
    try {
      // Initialize offline-first capabilities
      await initializeOfflineFirst();

      // Listen to MessageNotifier updates and sync to ChatState
      ref.listen<AsyncValue<MessageState>>(messageNotifierProvider,
          (prev, next) {
        next.whenData((messageState) {
          _syncMessagesFromMessageNotifier(messageState);
        });
      });

      return ChatState.initial();
    } catch (e) {
      // Note: _errorHandler not yet initialized, use basic logging
      debugPrint('ChatNotifier build error: $e');
      rethrow;
    }
  }

  /// Sync messages from MessageNotifier to ChatNotifier state
  void _syncMessagesFromMessageNotifier(MessageState messageState) {
    state.whenData((chatState) {
      // Only update if messages have changed
      if (chatState.chatMessages != messageState.messages) {
        debugPrint(
            'ChatNotifier: Syncing ${messageState.messages.length} message groups from MessageNotifier');
        state = AsyncValue.data(chatState.copyWith(
          chatMessages: messageState.messages,
        ));
      }
    });
  }

  // ============================================================================
  // INITIALIZATION & COORDINATION
  // ============================================================================

  /// Initialize chat for a specific group
  /// Delegates message streaming to MessageNotifier
  Future<void> initializeChat(String chatGroupId, ChatType chatType) async {
    await future;

    if (_currentChatGroupId != chatGroupId || _currentChatType != chatType) {
      await _disposePresenceChannel();
      _currentChatGroupId = chatGroupId;
      _currentChatType = chatType;
    }

    // Initialize presence tracking
    _initializePresenceChannel(chatGroupId);

    // Initialize message streaming via MessageNotifier
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    await messageNotifier.initializeMessagesStream(chatGroupId, chatType);

    // Load active polls via MediaNotifier (polls are stored in chat_messages.poll JSONB, not separate table)
    // Skip for now as polls table doesn't exist
    try {
      final mediaNotifier = ref.read(mediaNotifierProvider.notifier);
      await mediaNotifier.loadActivePolls(chatGroupId);
    } catch (e) {
      debugPrint(
          '⚠️ Skipping polls loading (polls stored in chat_messages): $e');
    }

    // Update selected chat group in state
    await selectChatGroup(chatGroupId);
  }

  // ============================================================================
  // PRESENCE TRACKING
  // ============================================================================

  void _initializePresenceChannel(String chatGroupId) {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      _presenceChannel = supabase.channel('presence:$chatGroupId');

      _presenceChannel!.onPresenceSync((_) {
        final presenceState = _presenceChannel!.presenceState();
        debugPrint(
            'ChatNotifier: Presence sync - ${presenceState.length} users online');
        _updateOnlineUsers(chatGroupId, presenceState);
      }).onPresenceJoin((payload) {
        debugPrint('ChatNotifier: User joined - $payload');
      }).onPresenceLeave((payload) {
        debugPrint('ChatNotifier: User left - $payload');
      }).subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _presenceChannel!.track({
            'user_id': currentUser.id,
            'display_name': currentUser.userMetadata?['display_name'] ??
                currentUser.email ??
                'Unknown',
            'online_at': DateTime.now().toIso8601String(),
          });
          debugPrint('ChatNotifier: Presence tracking enabled');
        }
      });

      debugPrint('ChatNotifier: Presence channel initialized for $chatGroupId');
    } catch (e) {
      debugPrint('ChatNotifier: Failed to initialize presence channel: $e');
    }
  }

  Future<void> _updateOnlineUsers(
      String chatGroupId, List<SinglePresenceState> presenceState) async {
    try {
      final onlineUserIds = <String>{};

      for (final state in presenceState) {
        for (final presence in state.presences) {
          final payload = presence.payload;
          final userId = payload['user_id'] as String?;
          if (userId != null) {
            onlineUserIds.add(userId);
          }
        }
      }

      debugPrint(
          'ChatNotifier: ${onlineUserIds.length} users online in $chatGroupId');
    } catch (e) {
      debugPrint('ChatNotifier: Error updating online users: $e');
    }
  }

  Future<void> _disposePresenceChannel() async {
    if (_presenceChannel != null) {
      await supabase.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
    _currentChatGroupId = null;
    _currentChatType = null;
  }

  // ============================================================================
  // MESSAGE OPERATIONS (Delegated to MessageNotifier)
  // ============================================================================

  Future<void> sendMessage(WidgetRef ref, String chatGroupId, String text,
      MessageType messageType, ChatType chatType,
      {String? mediaUrl,
      String? mediaType,
      String? replyTo,
      Poll? poll,
      String? voiceNoteUrl,
      int? voiceNoteDuration,
      String? mediaFilePath,
      String? clipFilePath}) async {
    try {
      // Handle clip processing via MediaNotifier
      if (messageType == MessageType.clip && clipFilePath != null) {
        final mediaNotifier = ref.read(mediaNotifierProvider.notifier);
        final clipData = await mediaNotifier.processClip(clipFilePath);

        mediaUrl = clipData['videoUrl'] as String;
        mediaType = 'video/mp4';

        // Send message with clip data
        final messageNotifier = ref.read(messageNotifierProvider.notifier);
        await messageNotifier.sendMessage(
          ref,
          chatGroupId,
          text,
          messageType,
          chatType,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          replyTo: replyTo,
          mediaFilePath: mediaFilePath,
        );
      } else {
        // Regular message - delegate to MessageNotifier
        final messageNotifier = ref.read(messageNotifierProvider.notifier);
        await messageNotifier.sendMessage(
          ref,
          chatGroupId,
          text,
          messageType,
          chatType,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          replyTo: replyTo,
          mediaFilePath: mediaFilePath,
        );
      }
    } catch (e) {
      debugPrint('ChatNotifier: Send message failed: $e');
      rethrow;
    }
  }

  Future<void> loadMessages(String chatGroupId,
      {int limit = 50, DateTime? before}) async {
    // Delegate to MessageNotifier
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    await messageNotifier.initializeMessagesStream(
        chatGroupId, _currentChatType ?? ChatType.squad);
  }

  // ============================================================================
  // REACTIONS (Delegated to MessageNotifier)
  // ============================================================================

  Future<void> addReaction(
      String chatGroupId, String messageId, String reaction) async {
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    await messageNotifier.addReaction(chatGroupId, messageId, reaction);
  }

  Future<void> removeReaction(
      String chatGroupId, String messageId, String reaction) async {
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    await messageNotifier.removeReaction(chatGroupId, messageId, reaction);
  }

  // ============================================================================
  // POLLS (Delegated to MediaNotifier)
  // ============================================================================

  Future<void> createPoll(
      String chatGroupId, String question, List<String> options) async {
    final mediaNotifier = ref.read(mediaNotifierProvider.notifier);
    await mediaNotifier.createPoll(chatGroupId, question, options);
  }

  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId) async {
    final mediaNotifier = ref.read(mediaNotifierProvider.notifier);
    await mediaNotifier.votePoll(chatGroupId, pollId, option, voterId);
  }

  // ============================================================================
  // MEDIA (Delegated to MediaNotifier)
  // ============================================================================

  Future<String> uploadMedia(String filePath, String mediaType) async {
    final mediaNotifier = ref.read(mediaNotifierProvider.notifier);
    return await mediaNotifier.uploadMedia(filePath, mediaType);
  }

  Future<void> loadMediaHistory(String chatGroupId) async {
    final mediaNotifier = ref.read(mediaNotifierProvider.notifier);
    await mediaNotifier.loadMediaHistory(chatGroupId);
  }

  Future<void> incrementClipViews(
      String chatGroupId, String messageId, ChatType chatType) async {
    final mediaNotifier = ref.read(mediaNotifierProvider.notifier);
    await mediaNotifier.incrementClipViews(chatGroupId, messageId, chatType);
  }

  Future<void> toggleClipHype(
      String chatGroupId, String messageId, ChatType chatType) async {
    final mediaNotifier = ref.read(mediaNotifierProvider.notifier);
    await mediaNotifier.toggleClipHype(chatGroupId, messageId, chatType);
  }

  // ============================================================================
  // GROUP MANAGEMENT
  // ============================================================================

  /// Load all groups the current user is a member of
  /// Populates chatGroups and userChatGroups in state
  Future<void> loadUserGroups() async {
    debugPrint('🔵 loadUserGroups() CALLED - START');
    await future;
    debugPrint('🔵 loadUserGroups() - future awaited');

    try {
      final currentUser = _authService.currentUser;
      debugPrint('🔵 loadUserGroups() - currentUser: ${currentUser?.id}');
      if (currentUser == null) {
        debugPrint('⚠️ Cannot load user groups: No authenticated user');
        return;
      }

      debugPrint('📚 Loading user groups for: ${currentUser.id}');

      // Query user's groups from users.user_groups JSONB field
      debugPrint('🔍 Step 1: Querying users table for user_groups...');
      dynamic userData;
      try {
        userData = await SupabaseService.client
            .from('users')
            .select('user_groups')
            .eq('uid', currentUser.id)
            .maybeSingle();
        debugPrint('🔍 Step 2: Query successful! userData: $userData');
      } catch (queryError) {
        debugPrint('❌ Step 1 FAILED with error: $queryError');
        debugPrint('❌ Error type: ${queryError.runtimeType}');
        rethrow;
      }

      debugPrint('🔍 Step 2: userData received: ${userData != null}');
      if (userData == null || userData['user_groups'] == null) {
        debugPrint('📚 No user groups found in userData');
        return;
      }

      debugPrint('🔍 Step 3: Parsing user_groups JSONB...');
      final userGroupsData =
          List<Map<String, dynamic>>.from(userData['user_groups'] ?? []);
      debugPrint('🔍 Step 4: Found ${userGroupsData.length} group entries');

      final groupIds = userGroupsData
          .map((g) => g['chat_group_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();
      debugPrint(
          '🔍 Step 5: Extracted ${groupIds.length} group IDs: $groupIds');

      if (groupIds.isEmpty) {
        debugPrint('📚 User has no group IDs');
        return;
      }

      // Fetch full group details
      debugPrint('🔍 Step 6: Querying chat_groups table...');
      final groupsData = await SupabaseService.client
          .from('chat_groups')
          .select()
          .inFilter('id', groupIds);
      debugPrint(
          '🔍 Step 7: Received ${(groupsData as List).length} groups from database');

      final groups = <String, ChatGroup>{};
      for (var data in (groupsData as List<dynamic>)) {
        final groupData = data as Map<String, dynamic>;
        final group = ChatGroup(
          id: groupData['id'] as String,
          name: groupData['name'] as String,
          isPublic: groupData['is_public'] as bool? ?? false,
          memberUids: List<String>.from(groupData['member_uids'] ?? []),
          memberCount: (groupData['member_uids'] as List?)?.length ?? 0,
          createdBy: groupData['created_by'] as String? ?? 'unknown',
          createdAt: groupData['created_at'] != null
              ? DateTime.parse(groupData['created_at'] as String)
              : DateTime.now(),
          description: groupData['description'] as String?,
          avatarUrl: groupData['avatar_url'] as String?,
          inviteCode: groupData['id'] as String, // Use group ID as invite code
          lastActivity: groupData['last_message_time'] != null
              ? DateTime.parse(groupData['last_message_time'] as String)
              : null,
        );
        groups[group.id] = group;
      }

      debugPrint('✅ Loaded ${groups.length} user groups');
      debugPrint('📚 Group IDs: ${groups.keys.toList()}');

      // Update state - force rebuild with AsyncData
      final currentState = state.valueOrNull ?? await future;
      debugPrint(
          '📚 Current state chatGroups: ${currentState.chatGroups.length}');
      final newState = currentState.copyWith(
        chatGroups: groups,
        userChatGroups: groups,
      );
      debugPrint('📚 New state chatGroups: ${newState.chatGroups.length}');
      state = AsyncData(newState);
      debugPrint(
          '📚 State set successfully - value check: ${state.valueOrNull?.chatGroups.length}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading user groups: $e');
      debugPrint('Stack trace: $stackTrace');
      await _errorHandler.handleError(
        error: e,
        stackTrace: stackTrace,
        operation: 'loadUserGroups',
        showSnackBar: false,
      );
    }
  }

  Future<ChatGroup?> createGroup(String name, bool isPublic,
      {String? description}) async {
    await future;
    final group =
        await _repository.createGroup(name, isPublic, description: description);
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedGroups =
          Map<String, ChatGroup>.from(currentState.chatGroups);
      updatedGroups[group.id] = group;
      return currentState.copyWith(chatGroups: updatedGroups);
    });
    return group;
  }

  Future<void> joinGroup(String groupId) async {
    await future;
    await _repository.joinGroup(groupId);
  }

  Future<void> leaveGroup(String groupId) async {
    await future;
    await _repository.leaveGroup(groupId);
  }

  /// Discover public groups, optionally filtered by game
  /// Returns list ordered by member count DESC, limited to 20
  Future<List<ChatGroup>> discoverGroups({String? gameFilter}) async {
    // Ensure notifier is initialized before accessing dependencies
    await future;

    try {
      // Call repository to fetch public groups
      final groups = await _repository.discoverGroups(
        query: gameFilter,
        limit: 20,
      );

      // Sort by member count descending
      groups.sort((a, b) => b.memberCount.compareTo(a.memberCount));

      return groups;
    } catch (e, stackTrace) {
      debugPrint('Error discovering groups: $e');
      debugPrint('Stack trace: $stackTrace');
      await _errorHandler.handleError(
        error: e,
        stackTrace: stackTrace,
        operation: 'discoverGroups',
        showSnackBar: false,
      );
      return [];
    }
  }

  /// Join a group with confirmation dialog
  /// Shows member count and group name before joining
  Future<void> joinGroupWithConfirmation(
    BuildContext context,
    String groupId,
  ) async {
    await future;
    try {
      // Fetch group details first - check cache, then fetch from DB if not found
      final currentState = state.value ?? await future;
      ChatGroup? group = currentState.chatGroups[groupId];

      // If not in cache (e.g., from discover list), fetch from database
      if (group == null) {
        debugPrint(
            '🔍 Group $groupId not in cache, fetching from remote datasource...');
        try {
          // Use remote datasource directly to fetch group by ID
          final remoteDataSource = ref.read(chatRemoteDataSourceProvider);
          group = await remoteDataSource.getChatGroup(groupId);
        } catch (e) {
          debugPrint('❌ Failed to fetch group from database: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Group not found')),
            );
          }
          return;
        }
      }

      if (group == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group not found')),
          );
        }
        return;
      }

      // Show confirmation dialog
      final inviteCodeDisplay =
          group.inviteCode != null && group.inviteCode!.isNotEmpty
              ? '\nCode: ${group.inviteCode}'
              : '';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Join ${group?.name ?? "Group"}?'),
          content: Text(
            '${group?.memberCount ?? 0} ${(group?.memberCount ?? 0) == 1 ? "member" : "members"}$inviteCodeDisplay',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Join'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Join the group
      await _repository.joinGroup(groupId);

      // Invalidate to force reload from Supabase for realtime update
      ref.invalidateSelf();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully joined ${group.name}!')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error joining group: $e');
      debugPrint('Stack trace: $stackTrace');
      await _errorHandler.handleError(
        error: e,
        stackTrace: stackTrace,
        operation: 'joinGroup',
        showSnackBar: false,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join group: $e')),
        );
      }
    }
  }

  /// Join a group by invite code
  /// Validates UUID format and fetches group before joining
  Future<void> joinByInviteCode(
    BuildContext context,
    String code,
  ) async {
    await future;
    try {
      // Validate UUID format
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );

      if (!uuidRegex.hasMatch(code.trim())) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid invite code format')),
          );
        }
        throw Exception('Invalid UUID format');
      }

      // Fetch group by invite code (using group ID as invite code)
      final currentState = state.value ?? await future;
      final group = currentState.chatGroups[code.trim()];

      if (group == null) {
        // Try to fetch from repository if not in local state
        try {
          final groups = await _repository.discoverGroups(
            query: null,
            limit: 100,
          );

          final matchedGroup = groups.firstWhere(
            (g) => g.id == code.trim() || g.inviteCode == code.trim(),
            orElse: () => throw Exception('Group not found'),
          );

          // Join the found group
          await joinGroupWithConfirmation(context, matchedGroup.id);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid code - group not found')),
            );
          }
        }
        return;
      }

      // Join the group if found in state
      await joinGroupWithConfirmation(context, group.id);
    } catch (e, stackTrace) {
      debugPrint('Error joining by invite code: $e');
      debugPrint('Stack trace: $stackTrace');
      await _errorHandler.handleError(
        error: e,
        stackTrace: stackTrace,
        operation: 'joinByInviteCode',
        showSnackBar: false,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join by invite code: $e')),
        );
      }
    }
  }

  /// Create a preset group (e.g., from lobby members)
  /// Preset options: 'lobby' - loads members from current lobby
  Future<ChatGroup?> createPresetGroup({
    String preset = 'lobby',
    BuildContext? context,
  }) async {
    await future;
    try {
      List<String> memberUids = [];
      String groupName = 'Squad Chat';

      if (preset == 'lobby') {
        // Load members from current lobby
        final lobbyState = ref.read(lobbyNotifierProvider).value;
        memberUids = lobbyState?.lobbyMemberUids ?? [];

        if (memberUids.isEmpty) {
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No lobby members found')),
            );
          }
          return null;
        }

        // Get current game name for auto-naming
        final gameState = ref.read(gameNotifierProvider).value;
        final gameName = gameState?.currentGame?.name;
        groupName = '${gameName ?? 'Squad'} Chat';
      }

      // Create the group
      final group = await _repository.createGroup(
        groupName,
        false, // isPublic = false for preset groups
        description: 'Created from $preset preset',
      );

      // Update state with new group
      state = await AsyncValue.guard(() async {
        final currentState = state.value ?? await future;
        final updatedGroups =
            Map<String, ChatGroup>.from(currentState.chatGroups);
        updatedGroups[group.id] = group;
        return currentState.copyWith(chatGroups: updatedGroups);
      });

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$groupName" created successfully!')),
        );
      }

      return group;
    } catch (e, stackTrace) {
      debugPrint('Error creating preset group: $e');
      debugPrint('Stack trace: $stackTrace');
      await _errorHandler.handleError(
        error: e,
        stackTrace: stackTrace,
        operation: 'createPresetGroup',
        showSnackBar: false,
      );

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
      return null;
    }
  }

  // ============================================================================
  // TYPING INDICATORS (Delegated to MessageNotifier)
  // ============================================================================

  Future<void> updateTypingIndicator(String chatGroupId, bool isTyping) async {
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    await messageNotifier.updateTypingIndicator(chatGroupId, isTyping);
  }

  // ============================================================================
  // PINNING
  // ============================================================================

  Future<void> pinMessage(String chatGroupId, String messageId) async {
    await future;
    await _repository.pinMessage(chatGroupId, messageId);
  }

  // ============================================================================
  // UI STATE MANAGEMENT
  // ============================================================================

  Future<void> selectChatGroup(String? groupId) async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(selectedChatGroupId: groupId);
    });
  }

  Future<void> setReplyingToMessage(String? messageId) async {
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    await messageNotifier.setReplyingToMessage(messageId);
  }

  Future<void> setReplyingToMessageObject(Message? message) async {
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    await messageNotifier.setReplyingToMessageObject(message);
  }

  Future<void> clearReplyToMessage() async {
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    await messageNotifier.clearReplyToMessage();
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  Future<void> performSync() async {
    // TODO: Implement delta sync if needed
  }

  Future<void> clearSyncError() async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(syncError: null);
    });
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  List<Message> getMessagesForGroup(String chatGroupId) {
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    return messageNotifier.getMessagesForGroup(chatGroupId);
  }

  Set<String> getTypingUsers(String chatGroupId) {
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    return messageNotifier.getTypingUsers(chatGroupId);
  }

  int getUnreadCount(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => data.unreadCounts[chatGroupId] ?? 0,
      orElse: () => 0,
    );
  }

  bool isUserTyping(String chatGroupId, String userId) {
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    return messageNotifier.isUserTyping(chatGroupId, userId);
  }

  List<Map<String, dynamic>> getMediaHistory() {
    final mediaNotifier = ref.read(mediaNotifierProvider.notifier);
    return mediaNotifier.getMediaHistory();
  }

  Map<String, Poll> getActivePolls(String chatGroupId) {
    final mediaNotifier = ref.read(mediaNotifierProvider.notifier);
    return mediaNotifier.getActivePolls(chatGroupId);
  }

  // Dispose (handled automatically by AutoDisposeAsyncNotifier)
  void dispose() {
    _disposePresenceChannel();
    // Clean up offline-first resources
    disposeOfflineFirst();
  }
}

// ChatNotifier provider - uses AsyncNotifier (not AutoDispose) to persist state
final chatNotifierProvider = AsyncNotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
