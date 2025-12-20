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

      // Register cleanup callback to prevent channel leaks
      ref.onDispose(() {
        debugPrint('ChatNotifier: Disposing presence channel');
        _disposePresenceChannel();
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
      // Check if any relevant state has changed
      final messagesChanged = chatState.chatMessages != messageState.messages;
      final replyChanged =
          chatState.replyToMessage != messageState.replyToMessage;
      final typingChanged =
          chatState.typingIndicators != messageState.typingUsers;

      if (messagesChanged || replyChanged || typingChanged) {
        debugPrint(
            'ChatNotifier: Syncing from MessageNotifier (messages: $messagesChanged, reply: $replyChanged, typing: $typingChanged)');
        state = AsyncValue.data(chatState.copyWith(
          chatMessages: messageState.messages,
          replyToMessage: messageState.replyToMessage,
          replyingToMessageId: messageState.replyingToMessageId,
          typingIndicators: messageState.typingUsers,
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
    try {
      await future;

      // AGGRESSIVE cleanup if approaching limit
      if (SupabaseService.activeChannelCount > 80) {
        debugPrint(
            '🚨 HIGH CHANNEL COUNT: ${SupabaseService.activeChannelCount}');
        SupabaseService.logChannelUsage();

        // Remove ALL channels for this chat group first
        await _cleanupAllChannelsForChat(chatGroupId);

        // Give Supabase time to process removals
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (_currentChatGroupId != chatGroupId || _currentChatType != chatType) {
        await _disposePresenceChannel();
        _currentChatGroupId = chatGroupId;
        _currentChatType = chatType;
      }

      // Initialize presence tracking (await to ensure channel cleanup)
      await _initializePresenceChannel(chatGroupId);

      // Initialize message streaming via MessageNotifier
      final messageNotifier = ref.read(messageNotifierProvider.notifier);
      await messageNotifier.initializeMessagesStream(chatGroupId, chatType);
    } on RealtimeSubscribeException catch (e, stackTrace) {
      debugPrint(
          '❌ ChatNotifier: RealtimeSubscribeException during init: ${e.status}');
      debugPrint('❌ Details: ${e.details}');
      if (e.status == RealtimeSubscribeStatus.channelError) {
        await SupabaseService.cleanupOldChannels();
      }
      // Don't throw - allow chat to continue without real-time features
    } catch (e, stackTrace) {
      debugPrint('❌ ChatNotifier: Error initializing chat: $e');
      debugPrint(
          '❌ Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      // Don't throw - allow chat to continue without real-time features
      // User will see cached messages but real-time updates may be degraded
    }

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

  Future<void> _initializePresenceChannel(String chatGroupId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ ChatNotifier: No user, skipping presence channel');
        return;
      }

      // Proactive cleanup if approaching channel limit
      if (SupabaseService.isApproachingChannelLimit) {
        debugPrint('ChatNotifier: ⚠️ Approaching channel limit, cleaning up');
        await SupabaseService.cleanupOldChannels();
      }

      // Remove existing channel first to avoid duplicates
      if (_presenceChannel != null) {
        try {
          await supabase.removeChannel(_presenceChannel!);
        } catch (e) {
          debugPrint('⚠️ Warning: Failed to remove old presence channel: $e');
        }
        _presenceChannel = null;
      }

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
        try {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Null safety check before tracking
            if (_presenceChannel != null) {
              await _presenceChannel!.track({
                'user_id': currentUser.id,
                'display_name': currentUser.userMetadata?['display_name'] ??
                    currentUser.email ??
                    'Unknown',
                'online_at': DateTime.now().toIso8601String(),
              });
              debugPrint('ChatNotifier: Presence tracking enabled');
            }
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            debugPrint(
                '❌ ChatNotifier: Presence channel error/timeout: $status - $error');
            // Cleanup on error - don't let this block chat functionality
            if (_presenceChannel != null) {
              await SupabaseService.safeRemoveChannel(_presenceChannel!);
              _presenceChannel = null;
            }
            // Trigger cleanup if error present
            if (error != null) {
              await SupabaseService.cleanupOldChannels();
            }
          }
        } catch (e) {
          debugPrint('❌ ChatNotifier: Error in subscribe callback: $e');
          // Cleanup on exception
          if (_presenceChannel != null) {
            await SupabaseService.safeRemoveChannel(_presenceChannel!);
            _presenceChannel = null;
          }
        }
      });

      debugPrint('ChatNotifier: Presence channel initialized for $chatGroupId');
    } catch (e) {
      debugPrint('⚠️ ChatNotifier: Failed to initialize presence channel: $e');
      // Don't throw - presence is nice-to-have, not critical
      _presenceChannel = null;
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
      await SupabaseService.safeRemoveChannel(_presenceChannel!);
      _presenceChannel = null;
    }
    _currentChatGroupId = null;
    _currentChatType = null;
  }

  /// Clean up ALL channels for a specific chat (presence, typing, messages)
  Future<void> _cleanupAllChannelsForChat(String chatGroupId) async {
    try {
      // Clean up all channels - we can't filter by topic anymore
      final channels = supabase.getChannels();

      debugPrint(
          '🧹 Cleaning ${channels.length} channels for chat $chatGroupId');

      // Remove all channels to ensure clean state
      for (final channel in channels) {
        await SupabaseService.safeRemoveChannel(channel);
      }
    } catch (e) {
      debugPrint('⚠️ Error in _cleanupAllChannelsForChat: $e');
    }
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

  /// Load all groups the current user is a member of (squad, userGroup, dm)
  /// Queries chat_groups.member_uids directly - no longer uses users.user_groups JSONB
  /// Populates both chatGroups and userChatGroups in state
  Future<void> loadUserGroups() async {
    debugPrint('🔵 loadUserGroups() CALLED - Loading ALL chat groups');
    await future;

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ Cannot load groups: No authenticated user');
        return;
      }

      debugPrint('📚 Loading ALL groups for user: ${currentUser.id}');

      // Query ALL groups where user is a member by checking member_uids array
      // This includes squad chats, user groups, and DMs
      debugPrint('🔍 Querying chat_groups where user is in member_uids...');
      final groupsData = await SupabaseService.client
          .from('chat_groups')
          .select('*')
          .contains('member_uids', [currentUser.id]);

      debugPrint('🔍 Received ${(groupsData as List).length} total groups');

      if ((groupsData as List).isEmpty) {
        debugPrint('📚 User is not a member of any groups');
        // Set empty state
        final currentState = state.valueOrNull ?? await future;
        state = AsyncData(currentState.copyWith(
          chatGroups: {},
          userChatGroups: {},
        ));
        return;
      }

      final allGroups = <String, ChatGroup>{};
      final userOnlyGroups = <String, ChatGroup>{};

      for (var data in (groupsData as List<dynamic>)) {
        final groupData = data as Map<String, dynamic>;
        final groupId = groupData['id'] as String;

        // Query the most recent message for this group to get last activity and details
        DateTime? lastActivity;
        String? lastMessageText;
        String? lastMessageSenderName;
        try {
          final lastMessageData = await SupabaseService.client
              .from('chat_messages')
              .select('created_at, text, sender_id')
              .eq('chat_id', groupId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (lastMessageData != null) {
            if (lastMessageData['created_at'] != null) {
              lastActivity =
                  DateTime.parse(lastMessageData['created_at'] as String);
            }
            lastMessageText = lastMessageData['text'] as String?;

            // Fetch sender's display name
            final senderId = lastMessageData['sender_id'] as String?;
            if (senderId != null) {
              try {
                final userData = await SupabaseService.client
                    .from('users')
                    .select('display_name')
                    .eq('uid', senderId)
                    .maybeSingle();
                lastMessageSenderName = userData?['display_name'] as String?;
              } catch (e) {
                debugPrint('⚠️ Could not fetch sender name: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Could not fetch last message for group $groupId: $e');
        }

        final group = ChatGroup(
          id: groupId,
          name: groupData['name'] as String? ?? 'Unnamed Group',
          isPublic: groupData['is_public'] as bool? ?? false,
          memberUids: List<String>.from(groupData['member_uids'] ?? []),
          memberCount: (groupData['member_uids'] as List?)?.length ?? 0,
          createdBy: groupData['created_by'] as String? ?? 'unknown',
          createdAt: groupData['created_at'] != null
              ? DateTime.parse(groupData['created_at'] as String)
              : DateTime.now(),
          description: groupData['description'] as String?,
          avatarUrl: groupData['avatar_url'] as String?,
          inviteCode: groupData['invite_code'] as String? ?? groupId,
          lastActivity: lastActivity,
          metadata: {
            ...?groupData['metadata'] as Map<String, dynamic>?,
            if (lastMessageText != null) 'last_message_text': lastMessageText,
            if (lastMessageSenderName != null)
              'last_message_sender': lastMessageSenderName,
          },
        );

        allGroups[group.id] = group;

        // Keep backward compatibility: userChatGroups contains same as chatGroups
        // (Previously filtered out squad chats, but user wants to see ALL)
        userOnlyGroups[group.id] = group;
      }

      debugPrint('✅ Loaded ${allGroups.length} total groups');
      debugPrint('📚 Group IDs: ${allGroups.keys.toList()}');

      // Update state with all groups
      final currentState = state.valueOrNull ?? await future;
      final newState = currentState.copyWith(
        chatGroups: allGroups,
        userChatGroups: userOnlyGroups, // Now same as chatGroups
      );
      state = AsyncData(newState);
      debugPrint(
          '📚 State updated - showing ${allGroups.length} groups in chats tab');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading groups: $e');
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

    // Auto-friend all members in private groups
    if (!isPublic) {
      await _autoFriendGroupMembers(group.id);
    }

    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedGroups =
          Map<String, ChatGroup>.from(currentState.chatGroups);
      updatedGroups[group.id] = group;
      return currentState.copyWith(chatGroups: updatedGroups);
    });
    return group;
  }

  /// Auto-friend all members when joining a private chat group
  Future<void> _autoFriendGroupMembers(String chatGroupId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Get all members of the chat group
      final response = await SupabaseService.client
          .from('chat_group_members')
          .select('user_id')
          .eq('chat_group_id', chatGroupId);

      final memberIds = (response as List)
          .map((m) => m['user_id'] as String)
          .where((id) => id != user.id) // Exclude self
          .toList();

      // Add all members as friends
      for (final memberId in memberIds) {
        try {
          await SupabaseService.client.rpc('add_friend', params: {
            'user_id_1': user.id,
            'user_id_2': memberId,
          });
        } catch (e) {
          debugPrint('Failed to auto-friend $memberId: $e');
          // Continue with other members even if one fails
        }
      }

      debugPrint('✅ Auto-friended ${memberIds.length} users from private chat');
    } catch (e) {
      debugPrint('Error auto-friending chat members: $e');
      // Non-critical error, don't throw
    }
  }

  Future<void> joinGroup(String groupId) async {
    await future;
    await _repository.joinGroup(groupId);

    // Check if group is private and auto-friend members
    final currentState = state.valueOrNull;
    if (currentState != null) {
      final group = currentState.chatGroups[groupId];
      if (group != null && !group.isPublic) {
        await _autoFriendGroupMembers(groupId);
      }
    }
  }

  Future<void> leaveGroup(String groupId) async {
    await future;
    await _repository.leaveGroup(groupId);
    // Invalidate state to trigger reload
    ref.invalidateSelf();
    // Reload user groups to update UI
    await loadUserGroups();
  }

  /// Toggle mute status for a group chat
  Future<void> toggleMuteGroup(String groupId, bool currentlyMuted) async {
    await _updateGroupMetadata(groupId, {
      'is_muted': !currentlyMuted,
      'muted_at': !currentlyMuted ? DateTime.now().toIso8601String() : null,
    });
  }

  /// Toggle pin status for a group chat
  Future<void> togglePinGroup(String groupId, bool currentlyPinned) async {
    await _updateGroupMetadata(groupId, {
      'is_pinned': !currentlyPinned,
      'pinned_at': !currentlyPinned ? DateTime.now().toIso8601String() : null,
    });
  }

  /// Mark a group chat as unread
  Future<void> markGroupAsUnread(String groupId) async {
    await _updateGroupMetadata(groupId, {
      'has_unread': true,
      'unread_count': 1,
      'last_read_at': null,
    });
  }

  /// Mark a group chat as read
  Future<void> markGroupAsRead(String groupId) async {
    await _updateGroupMetadata(groupId, {
      'has_unread': false,
      'unread_count': 0,
      'last_read_at': DateTime.now().toIso8601String(),
    });
  }

  /// Ignore a group chat (mute + hide from main list)
  Future<void> ignoreGroup(String groupId) async {
    await _updateGroupMetadata(groupId, {
      'is_ignored': true,
      'is_muted': true,
      'ignored_at': DateTime.now().toIso8601String(),
    });
  }

  /// Delete a group chat (creator only)
  Future<void> deleteGroup(String groupId) async {
    await future;
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      // Verify user is the creator
      final groupData = await SupabaseService.client
          .from('chat_groups')
          .select('created_by')
          .eq('id', groupId)
          .maybeSingle();

      if (groupData == null) return;
      if (groupData['created_by'] != currentUser.id) {
        throw Exception('Only the group creator can delete this chat');
      }

      // Delete all messages first
      await SupabaseService.client
          .from('chat_messages')
          .delete()
          .eq('chat_id', groupId);

      // Delete the group
      await SupabaseService.client
          .from('chat_groups')
          .delete()
          .eq('id', groupId);

      // Remove from all users' user_groups
      // Fetch all users and filter client-side since JSONB contains query is problematic
      final allUsers =
          await SupabaseService.client.from('users').select('uid, user_groups');

      for (final userData in (allUsers as List)) {
        final userGroups =
            List<Map<String, dynamic>>.from(userData['user_groups'] ?? []);
        final hadGroup = userGroups
            .any((g) => g['id'] == groupId || g['chat_group_id'] == groupId);

        if (hadGroup) {
          userGroups.removeWhere(
              (g) => g['id'] == groupId || g['chat_group_id'] == groupId);

          await SupabaseService.client.from('users').update({
            'user_groups': userGroups,
          }).eq('uid', userData['uid']);
        }
      }

      // Reload groups
      await loadUserGroups();
    } catch (e) {
      debugPrint('Error deleting group: $e');
      rethrow;
    }
  }

  /// Update group metadata in users.user_groups JSONB
  Future<void> _updateGroupMetadata(
      String groupId, Map<String, dynamic> metadata) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final userData = await SupabaseService.client
          .from('users')
          .select('user_groups')
          .eq('uid', currentUser.id)
          .maybeSingle();

      if (userData == null) return;

      final userGroups =
          List<Map<String, dynamic>>.from(userData['user_groups'] ?? []);
      final groupIndex = userGroups.indexWhere((g) => g['id'] == groupId);

      if (groupIndex != -1) {
        // Update metadata
        userGroups[groupIndex] = {...userGroups[groupIndex], ...metadata};

        await SupabaseService.client.from('users').update({
          'user_groups': userGroups,
        }).eq('uid', currentUser.id);

        // Reload groups to reflect changes
        await loadUserGroups();
      }
    } catch (e) {
      debugPrint('Error updating group metadata: $e');
      rethrow;
    }
  }

  /// Discover public groups, optionally filtered by game
  /// Returns list ordered by member count DESC, limited to 20
  /// Excludes groups the current user is already a member of
  Future<List<ChatGroup>> discoverGroups({String? gameFilter}) async {
    // Ensure notifier is initialized before accessing dependencies
    await future;

    try {
      // Get current user's groups to filter them out
      final currentState = state.valueOrNull ?? await future;
      final userGroupIds = currentState.chatGroups.keys.toSet();

      debugPrint(
          '🔍 User is member of ${userGroupIds.length} groups, filtering from discovery');

      // Call repository to fetch public groups
      final groups = await _repository.discoverGroups(
        query: gameFilter,
        limit: 20,
      );

      // Filter out groups the user is already a member of
      final filteredGroups =
          groups.where((group) => !userGroupIds.contains(group.id)).toList();

      debugPrint(
          '✅ Discovered ${groups.length} public groups, showing ${filteredGroups.length} after filtering');

      // Sort by member count descending
      filteredGroups.sort((a, b) => b.memberCount.compareTo(a.memberCount));

      return filteredGroups;
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

      // Reload user groups to include the newly joined group
      // This prevents groups from disappearing after join
      debugPrint('🔄 Reloading user groups after join...');
      await loadUserGroups();

      // Show success feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully joined ${group?.name ?? "group"}'),
            duration: const Duration(seconds: 2),
          ),
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
