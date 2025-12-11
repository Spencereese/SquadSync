import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service_supabase.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/data/datasources/chat_remote_datasource.dart';
import 'package:squad_sync/services/supabase_service.dart';

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Convert database snake_case to Dart camelCase for ChatGroup
  Map<String, dynamic> _convertFromDatabase(Map<String, dynamic> dbData) {
    return {
      'id': dbData['id'],
      'name': dbData['name'],
      'memberUids': dbData['member_uids'] ?? [],
      'isPublic': dbData['is_public'] ?? false,
      'memberCount': dbData['member_count'] ?? 0,
      'createdBy': dbData['created_by'] ?? '',
      'createdAt': dbData['created_at'] ?? DateTime.now().toIso8601String(),
      if (dbData['description'] != null) 'description': dbData['description'],
      if (dbData['avatar_url'] != null) 'avatarUrl': dbData['avatar_url'],
      if (dbData['metadata'] != null) 'metadata': dbData['metadata'],
      if (dbData['admins'] != null) 'admins': dbData['admins'],
      if (dbData['moderators'] != null) 'moderators': dbData['moderators'],
      if (dbData['is_active'] != null) 'isActive': dbData['is_active'],
      if (dbData['last_activity'] != null)
        'lastActivity': dbData['last_activity'],
      if (dbData['settings'] != null) 'settings': dbData['settings'],
    };
  }

  @override
  Future<Message> sendMessage(
      String chatGroupId, Message message, ChatType chatType) async {
    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final messageData = {
      ...message.toJson(),
      'chat_id': chatGroupId,
      'chat_type': chatType.toString().split('.').last,
      'sender_id': currentUser.id,
      'timestamp': message.timestamp.toIso8601String(),
    };

    await _supabase.from('chat_messages').insert(messageData);
    return message;
  }

  @override
  Future<List<Message>> fetchMessages(String chatGroupId,
      {int limit = 50, DateTime? before}) async {
    // Use filter method for proper query building
    final response = before != null
        ? await _supabase
            .from('chat_messages')
            .select()
            .eq('chat_id', chatGroupId)
            .eq('is_deleted', false)
            .filter('timestamp', 'lt', before.toIso8601String())
            .order('timestamp', ascending: false)
            .limit(limit)
        : await _supabase
            .from('chat_messages')
            .select()
            .eq('chat_id', chatGroupId)
            .eq('is_deleted', false)
            .order('timestamp', ascending: false)
            .limit(limit);

    return (response as List<dynamic>)
        .map((data) => Message.fromJson(data as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteMessage(String chatGroupId, String messageId) async {
    await _supabase
        .from('chat_messages')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('chat_id', chatGroupId);
  }

  @override
  Future<void> editMessage(
      String chatGroupId, String messageId, String newText) async {
    await _supabase
        .from('chat_messages')
        .update({
          'text': newText,
          'is_edited': true,
          'edited_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('chat_id', chatGroupId);
  }

  @override
  Stream<List<Message>> watchMessages(String chatGroupId) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(100)
        .map((data) {
          // Filter in Dart since stream builder doesn't support all filters
          final filtered = data
              .where((item) =>
                  item['chat_id'] == chatGroupId &&
                  (item['is_deleted'] == false || item['is_deleted'] == null))
              .toList();
          return filtered.map((item) => Message.fromJson(item)).toList();
        });
  }

  @override
  Stream<Map<String, Set<String>>> watchTypingIndicators(String chatGroupId) {
    return _supabase
        .from('typing_indicators')
        .stream(primaryKey: ['id']).map((data) {
      final typing = <String, Set<String>>{};
      for (final item in data) {
        // Filter for this chat and active typing
        if (item['chat_id'] == chatGroupId && item['is_typing'] == true) {
          final userId = item['user_id'] as String;
          typing[userId] = {chatGroupId};
        }
      }
      return typing;
    });
  }

  @override
  Stream<Map<String, int>> watchUnreadCounts(String userId) {
    return _supabase
        .from('chat_read_states')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          final counts = <String, int>{};
          for (final item in data) {
            final chatId = item['chat_id'] as String;
            final count = item['unread_count'] as int? ?? 0;
            counts[chatId] = count;
          }
          return counts;
        });
  }

  @override
  Future<void> addReaction(String chatGroupId, String messageId, String userId,
      String reaction) async {
    // Get current reactions
    final response = await _supabase
        .from('chat_messages')
        .select('reactions')
        .eq('id', messageId)
        .single();

    final currentReactions =
        Map<String, dynamic>.from(response['reactions'] ?? {});
    currentReactions[userId] = reaction;

    await _supabase.from('chat_messages').update({
      'reactions': currentReactions,
    }).eq('id', messageId);
  }

  @override
  Future<void> removeReaction(String chatGroupId, String messageId,
      String userId, String reaction) async {
    // Get current reactions
    final response = await _supabase
        .from('chat_messages')
        .select('reactions')
        .eq('id', messageId)
        .single();

    final currentReactions =
        Map<String, dynamic>.from(response['reactions'] ?? {});
    currentReactions.remove(userId);

    await _supabase.from('chat_messages').update({
      'reactions': currentReactions,
    }).eq('id', messageId);
  }

  @override
  Future<Map<String, int>> getMessageReactions(
      String chatGroupId, String messageId) async {
    final response = await _supabase
        .from('chat_messages')
        .select('reactions')
        .eq('id', messageId)
        .single();

    final reactions = Map<String, dynamic>.from(response['reactions'] ?? {});
    final reactionCounts = <String, int>{};

    for (final reaction in reactions.values) {
      final reactionStr = reaction as String;
      reactionCounts[reactionStr] = (reactionCounts[reactionStr] ?? 0) + 1;
    }

    return reactionCounts;
  }

  @override
  Future<Poll> createPoll(String chatGroupId, Poll poll) async {
    await _supabase.from('polls').insert({
      'id': poll.id,
      'chat_id': chatGroupId,
      ...poll.toJson(),
    });

    return poll;
  }

  @override
  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId) async {
    // Get current poll data
    final response =
        await _supabase.from('polls').select('votes').eq('id', pollId).single();

    final currentVotes = Map<String, dynamic>.from(response['votes'] ?? {});
    currentVotes[voterId] = option;

    await _supabase.from('polls').update({
      'votes': currentVotes,
    }).eq('id', pollId);
  }

  @override
  Future<void> closePoll(String chatGroupId, String pollId) async {
    await _supabase.from('polls').update({
      'is_closed': true,
      'closed_at': DateTime.now().toIso8601String(),
    }).eq('id', pollId);
  }

  @override
  Future<String> uploadMedia(
      File file, String mediaType, String chatGroupId) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.path.split('.').last;
      final fileName = '${chatGroupId}_${timestamp}.$extension';
      final storagePath = 'chat_media/$fileName';

      // Read file as bytes
      final bytes = await file.readAsBytes();

      // Upload to Supabase Storage
      await _supabase.storage.from('chat-media').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getContentType(mediaType),
              upsert: false,
            ),
          );

      // Get public URL
      final downloadUrl =
          _supabase.storage.from('chat-media').getPublicUrl(storagePath);
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload media: $e');
    }
  }

  @override
  Future<void> deleteMedia(String mediaUrl) async {
    try {
      // Extract storage path from URL
      final uri = Uri.parse(mediaUrl);
      final pathSegments = uri.pathSegments;

      // Find the bucket and file path
      if (pathSegments.contains('chat-media')) {
        final bucketIndex = pathSegments.indexOf('chat-media');
        final filePath = pathSegments.skip(bucketIndex + 1).join('/');

        // Delete from Supabase Storage
        await _supabase.storage.from('chat-media').remove([filePath]);
      }
    } catch (e) {
      throw Exception('Failed to delete media: $e');
    }
  }

  /// Helper to determine content type
  String _getContentType(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'image':
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'video':
      case 'mp4':
        return 'video/mp4';
      case 'audio':
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Future<ChatGroup> createGroup(ChatGroup group) async {
    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    debugPrint('📝 Creating group: ${group.name}');
    debugPrint('   ID: ${group.id}');
    debugPrint('   Member UIDs: ${group.memberUids}');
    debugPrint('   Created by: ${group.createdBy}');

    // Ensure member_uids is never null or empty
    final memberUids =
        group.memberUids.isNotEmpty ? group.memberUids : [group.createdBy];

    debugPrint('   Final member_uids: $memberUids');

    // Manually map to snake_case for PostgreSQL
    // Let database generate ID if not provided, or use the provided one
    final groupData = {
      if (group.id.isNotEmpty) 'id': group.id,
      'name': group.name,
      'member_uids': memberUids, // Guaranteed to be non-empty array
      'is_public': group.isPublic,
      'created_by': group.createdBy,
      'created_at': group.createdAt.toIso8601String(),
      'is_dm': false,
      'game_focus': null,
    };

    debugPrint('   Inserting data: $groupData');

    try {
      final response = await _supabase
          .from('chat_groups')
          .insert(groupData)
          .select()
          .single();

      debugPrint('✅ Group created successfully: $response');

      // Update user's user_groups array
      final groupId = response['id'] as String;

      // Create a default lobby for this chat group to enable game lobbies
      debugPrint('🎮 Creating lobby for chat group: $groupId');
      try {
        final lobbyData = {
          'id':
              groupId, // Use same ID as chat group for backwards compatibility
          'chat_group_id': groupId, // Link to chat group
          'name': group.name,
          'member_uids': memberUids,
          'game_focus': null, // No specific game yet
          'max_spots': 8, // Default max spots
          'creator_uid': group.createdBy,
          'created_at': DateTime.now().toIso8601String(),
          'spot_timers': <String, dynamic>{}, // Empty timers
          'viewers': memberUids, // All members can view
          'statuses': <String, String>{}, // Empty statuses
          'is_active': true,
          'is_public': false, // Chat group lobbies are private by default
        };

        debugPrint('   Inserting lobby data: $lobbyData');
        await _supabase.from('lobbies').insert(lobbyData);
        debugPrint('✅ Created default lobby for chat group: $groupId');
      } catch (lobbyError) {
        debugPrint('❌ ERROR: Failed to create lobby for group: $lobbyError');
        // Rollback: delete the chat group since lobby creation failed
        try {
          await _supabase.from('chat_groups').delete().eq('id', groupId);
          debugPrint('🔄 Rolled back chat group creation due to lobby error');
        } catch (rollbackError) {
          debugPrint('❌ Rollback failed: $rollbackError');
        }
        // Re-throw the error to notify caller
        throw Exception('Failed to create lobby for chat group: $lobbyError');
      }

      try {
        final userResponse = await _supabase
            .from('users')
            .select('user_groups')
            .eq('uid', currentUser.id)
            .maybeSingle();

        final userGroups = userResponse != null
            ? List<Map<String, dynamic>>.from(userResponse['user_groups'] ?? [])
            : <Map<String, dynamic>>[];

        // Add new group to user_groups if not already there
        final existingIndex =
            userGroups.indexWhere((g) => g['chat_group_id'] == groupId);
        if (existingIndex == -1) {
          userGroups.add({
            'chat_group_id': groupId,
            'joined_at': DateTime.now().toIso8601String(),
          });

          await _supabase.from('users').update({
            'user_groups': userGroups,
          }).eq('uid', currentUser.id);

          debugPrint('✅ Updated user_groups for user ${currentUser.id}');
        }
      } catch (userUpdateError) {
        debugPrint(
            '⚠️ Warning: Failed to update user_groups: $userUpdateError');
        // Don't throw - group was created successfully, this is just cache update
      }

      // Convert database response and return as ChatGroup
      return ChatGroup.fromJson(_convertFromDatabase(response));
    } catch (e) {
      debugPrint('❌ Error creating group: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('   PostgreSQL Code: ${e.code}');
        debugPrint('   PostgreSQL Message: ${e.message}');
        debugPrint('   PostgreSQL Details: ${e.details}');
        debugPrint('   PostgreSQL Hint: ${e.hint}');
      }
      debugPrint('   Group data that failed: $groupData');
      debugPrint('   Current user auth.uid: ${_supabase.auth.currentUser?.id}');
      rethrow;
    }
  }

  @override
  Future<void> joinGroup(String groupId, String userId) async {
    // Get current members
    final response = await _supabase
        .from('chat_groups')
        .select('member_uids')
        .eq('id', groupId)
        .single();

    final currentMembers = List<String>.from(response['member_uids'] ?? []);
    if (!currentMembers.contains(userId)) {
      currentMembers.add(userId);

      await _supabase.from('chat_groups').update({
        'member_uids': currentMembers,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', groupId);
    }
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) async {
    // Get current members
    final response = await _supabase
        .from('chat_groups')
        .select('member_uids')
        .eq('id', groupId)
        .single();

    final currentMembers = List<String>.from(response['member_uids'] ?? []);
    currentMembers.remove(userId);

    await _supabase.from('chat_groups').update({
      'member_uids': currentMembers,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', groupId);
  }

  @override
  Future<List<ChatGroup>> discoverGroups(
      {String? query, int limit = 20}) async {
    var supabaseQuery =
        _supabase.from('chat_groups').select().eq('is_public', true);

    if (query != null && query.isNotEmpty) {
      supabaseQuery = supabaseQuery.ilike('name', '%$query%');
    }

    final response = await supabaseQuery.limit(limit);
    return (response as List<dynamic>)
        .map((data) => ChatGroup.fromJson(
            _convertFromDatabase(data as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<void> updateGroupSettings(
      String groupId, Map<String, dynamic> settings) async {
    await _supabase.from('chat_groups').update({
      ...settings,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', groupId);
  }

  @override
  Future<void> updateTypingIndicator(
      String chatGroupId, String userId, bool isTyping) async {
    if (!isTyping) {
      // Remove typing indicator
      await _supabase
          .from('typing_indicators')
          .delete()
          .eq('chat_id', chatGroupId)
          .eq('user_id', userId);
    } else {
      // Upsert typing indicator
      await _supabase.from('typing_indicators').upsert({
        'chat_id': chatGroupId,
        'user_id': userId,
        'is_typing': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<void> pinMessage(String chatGroupId, String messageId) async {
    await _supabase
        .from('chat_messages')
        .update({
          'metadata': {
            'is_pinned': true,
            'pinned_at': DateTime.now().toIso8601String(),
          },
        })
        .eq('id', messageId)
        .eq('chat_id', chatGroupId);
  }

  @override
  Future<void> unpinMessage(String chatGroupId, String messageId) async {
    await _supabase
        .from('chat_messages')
        .update({
          'metadata': {
            'is_pinned': false,
          },
        })
        .eq('id', messageId)
        .eq('chat_id', chatGroupId);
  }

  @override
  Future<String> getAiResponse(String message, String context) async {
    // TODO: Implement AI response integration (xAI Grok API)
    return "This is a placeholder AI response.";
  }

  @override
  Future<List<Message>> fetchMessagesSince(
      String chatGroupId, DateTime since) async {
    final response = await _supabase
        .from('chat_messages')
        .select()
        .eq('chat_id', chatGroupId)
        .eq('is_deleted', false)
        .gt('timestamp', since.toIso8601String())
        .order('timestamp', ascending: false);

    return (response as List<dynamic>)
        .map((data) => Message.fromJson(data as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> batchSyncMessages(
      String chatGroupId, List<Message> messages) async {
    final messagesData = messages
        .map((message) => {
              ...message.toJson(),
              'chat_id': chatGroupId,
            })
        .toList();

    await _supabase.from('chat_messages').upsert(messagesData);
  }

  @override
  Future<void> trackMessageEvent(String chatGroupId, String messageId,
      String event, Map<String, dynamic> data) async {
    // TODO: Implement analytics tracking via Supabase or external service
    // For now, this is a no-op
  }

  @override
  Future<void> startVoiceChat(
      String chatGroupId, List<String> participantIds) async {
    await _supabase.from('voice_rooms').insert({
      'id': chatGroupId,
      'chat_id': chatGroupId,
      'participant_uids': participantIds,
      'started_at': DateTime.now().toIso8601String(),
      'is_active': true,
    });
  }

  @override
  Future<void> endVoiceChat(String chatGroupId) async {
    await _supabase.from('voice_rooms').update({
      'is_active': false,
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('chat_id', chatGroupId);
  }

  @override
  Future<void> updateVoiceChatParticipants(
      String chatGroupId, List<String> participantIds) async {
    await _supabase.from('voice_rooms').update({
      'participant_uids': participantIds,
    }).eq('chat_id', chatGroupId);
  }
}
