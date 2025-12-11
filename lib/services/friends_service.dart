import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'supabase_service.dart';

/// Friends Service for Supabase
///
/// Handles all friend-related operations including:
/// - Friend requests (send, accept, decline)
/// - Friend management (add, remove, list)
/// - Direct messages
/// - User search
class FriendsService {
  final SupabaseClient _supabase = SupabaseService.client;
  final Logger _logger = Logger();

  // ============================================================================
  // USER SEARCH
  // ============================================================================

  /// Search users by display name with optional filters
  Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    String filter = 'all',
    int limit = 20,
  }) async {
    try {
      if (query.isEmpty || query.length < 2) return [];

      var queryBuilder = _supabase
          .from('users')
          .select(
              'uid, display_name, photo_url, email, last_seen_at, created_at')
          .ilike('display_name', '%$query%');

      // Apply filters based on filter type
      switch (filter) {
        case 'online':
          // Users active in the last 15 minutes
          final fifteenMinutesAgo = DateTime.now()
              .subtract(const Duration(minutes: 15))
              .toIso8601String();
          queryBuilder = queryBuilder.gte('last_seen_at', fifteenMinutesAgo);
          break;
        case 'recent':
          // Recently joined users (last 30 days)
          final thirtyDaysAgo = DateTime.now()
              .subtract(const Duration(days: 30))
              .toIso8601String();
          queryBuilder = queryBuilder.gte('created_at', thirtyDaysAgo);
          break;
        case 'all':
        default:
          // No additional filter
          break;
      }

      final response = await queryBuilder
          .order('display_name', ascending: true)
          .limit(limit);

      _logger.d(
          'Found ${response.length} users matching "$query" (filter: $filter)');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logger.e('Error searching users: $e');
      return [];
    }
  }

  /// Get user by UID
  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    try {
      final response = await _supabase
          .from('users')
          .select('uid, display_name, photo_url, email, last_seen_at')
          .eq('uid', uid)
          .maybeSingle();

      return response;
    } catch (e) {
      _logger.e('Error getting user $uid: $e');
      return null;
    }
  }

  // ============================================================================
  // FRIEND REQUESTS
  // ============================================================================

  /// Send a friend request
  Future<bool> sendFriendRequest(String currentUserId, String targetUserId,
      {String? message}) async {
    try {
      // Check if already friends
      final existingFriend = await _supabase
          .from('friends')
          .select()
          .eq('user_uid', currentUserId)
          .eq('friend_uid', targetUserId)
          .maybeSingle();

      if (existingFriend != null) {
        _logger.w('Already friends with $targetUserId');
        return false;
      }

      // Check if request already exists
      final existingRequest = await _supabase
          .from('friend_requests')
          .select()
          .eq('from_uid', currentUserId)
          .eq('to_uid', targetUserId)
          .maybeSingle();

      if (existingRequest != null) {
        _logger.w('Friend request already sent to $targetUserId');
        return false;
      }

      // Send request
      await _supabase.from('friend_requests').insert({
        'from_uid': currentUserId,
        'to_uid': targetUserId,
        'message': message,
        'status': 'pending',
      });

      _logger.i('Friend request sent to $targetUserId');
      return true;
    } catch (e) {
      _logger.e('Error sending friend request: $e');
      return false;
    }
  }

  /// Get pending friend requests (incoming)
  Stream<List<Map<String, dynamic>>> streamPendingRequests(String userId) {
    return _supabase
        .from('friend_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          // Filter in Dart since Supabase stream doesn't support chained eq()
          return data
              .where((item) =>
                  item['to_uid'] == userId && item['status'] == 'pending')
              .toList();
        });
  }

  /// Get pending friend requests with sender details
  Future<List<Map<String, dynamic>>> getPendingRequestsWithDetails(
      String userId) async {
    try {
      final requests = await _supabase
          .from('friend_requests')
          .select(
              '*, from_user:users!friend_requests_from_uid_fkey(uid, display_name, photo_url)')
          .eq('to_uid', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(requests);
    } catch (e) {
      _logger.e('Error getting pending requests: $e');
      return [];
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      // Call the PostgreSQL function that handles bidirectional friendship creation
      await _supabase
          .rpc('accept_friend_request', params: {'request_id': requestId});

      _logger.i('Friend request $requestId accepted');
      return true;
    } catch (e) {
      _logger.e('Error accepting friend request: $e');
      return false;
    }
  }

  /// Decline a friend request
  Future<bool> declineFriendRequest(String requestId) async {
    try {
      await _supabase.from('friend_requests').update({
        'status': 'declined',
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', requestId);

      _logger.i('Friend request $requestId declined');
      return true;
    } catch (e) {
      _logger.e('Error declining friend request: $e');
      return false;
    }
  }

  /// Cancel a sent friend request
  Future<bool> cancelFriendRequest(
      String currentUserId, String targetUserId) async {
    try {
      await _supabase
          .from('friend_requests')
          .delete()
          .eq('from_uid', currentUserId)
          .eq('to_uid', targetUserId)
          .eq('status', 'pending');

      _logger.i('Friend request to $targetUserId cancelled');
      return true;
    } catch (e) {
      _logger.e('Error cancelling friend request: $e');
      return false;
    }
  }

  // ============================================================================
  // FRIENDS MANAGEMENT
  // ============================================================================

  /// Stream friends list (real-time)
  Stream<List<Map<String, dynamic>>> streamFriends(String userId) {
    return _supabase
        .from('friends')
        .stream(primaryKey: ['id'])
        .eq('user_uid', userId)
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          // Filter in Dart for accepted status
          return data
              .where((item) =>
                  item['user_uid'] == userId && item['status'] == 'accepted')
              .toList();
        });
  }

  /// Get friends with user details
  Future<List<Map<String, dynamic>>> getFriendsWithDetails(
      String userId) async {
    try {
      final friends = await _supabase
          .from('friends')
          .select(
              '*, friend:users!friends_friend_uid_fkey(uid, display_name, photo_url, email)')
          .eq('user_uid', userId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(friends);
    } catch (e) {
      _logger.e('Error getting friends: $e');
      return [];
    }
  }

  /// Remove a friend (bidirectional)
  Future<bool> removeFriend(String currentUserId, String friendUid) async {
    try {
      // Call the PostgreSQL function that handles bidirectional removal
      await _supabase.rpc('remove_friendship', params: {
        'user1_uid': currentUserId,
        'user2_uid': friendUid,
      });

      _logger.i('Friendship with $friendUid removed');
      return true;
    } catch (e) {
      _logger.e('Error removing friend: $e');
      return false;
    }
  }

  /// Check if users are friends
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final friendship = await _supabase
          .from('friends')
          .select()
          .eq('user_uid', userId1)
          .eq('friend_uid', userId2)
          .eq('status', 'accepted')
          .maybeSingle();

      return friendship != null;
    } catch (e) {
      _logger.e('Error checking friendship: $e');
      return false;
    }
  }

  // ============================================================================
  // DIRECT MESSAGES
  // ============================================================================

  /// Start a DM thread (creates chat group if needed)
  Future<String?> startDMThread(String currentUserId, String friendUid) async {
    try {
      // Generate a consistent DM ID (always user1_user2 where user1 < user2 alphabetically)
      final users = [currentUserId, friendUid]..sort();
      final dmId = 'dm_${users[0]}_${users[1]}';

      // Check if DM chat group exists
      final existingDM = await _supabase
          .from('chat_groups')
          .select()
          .eq('id', dmId)
          .maybeSingle();

      if (existingDM == null) {
        // Create DM chat group
        await _supabase.from('chat_groups').insert({
          'id': dmId,
          'member_uids': [currentUserId, friendUid],
          'is_dm': true,
          'is_public': false,
          'created_by': currentUserId,
        });

        _logger.i('Created DM thread: $dmId');
      }

      return dmId;
    } catch (e) {
      _logger.e('Error starting DM thread: $e');
      return null;
    }
  }

  /// Send a direct message
  Future<bool> sendDirectMessage({
    required String senderId,
    required String recipientId,
    required String text,
    String messageType = 'text',
    String? mediaUrl,
    String? mediaType,
  }) async {
    try {
      final messageId =
          'dm_${DateTime.now().millisecondsSinceEpoch}_${senderId.substring(0, 8)}';

      await _supabase.from('direct_messages').insert({
        'id': messageId,
        'sender_uid': senderId,
        'recipient_uid': recipientId,
        'text': text,
        'message_type': messageType,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'is_read': false,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _logger.i('DM sent to $recipientId');
      return true;
    } catch (e) {
      _logger.e('Error sending DM: $e');
      return false;
    }
  }

  /// Stream DMs between two users (real-time)
  Stream<List<Map<String, dynamic>>> streamDirectMessages(
      String userId1, String userId2) {
    return _supabase
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(100)
        .asyncMap((data) async {
          // Filter in Dart for conversation between two users
          return data
              .where((item) =>
                  (item['sender_uid'] == userId1 &&
                      item['recipient_uid'] == userId2) ||
                  (item['sender_uid'] == userId2 &&
                      item['recipient_uid'] == userId1))
              .toList();
        });
  }

  /// Get DM conversation history
  Future<List<Map<String, dynamic>>> getDirectMessages(
      String userId1, String userId2,
      {int limit = 50}) async {
    try {
      final messages = await _supabase
          .from('direct_messages')
          .select()
          .or('and(sender_uid.eq.$userId1,recipient_uid.eq.$userId2),and(sender_uid.eq.$userId2,recipient_uid.eq.$userId1)')
          .order('timestamp', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(messages);
    } catch (e) {
      _logger.e('Error getting DMs: $e');
      return [];
    }
  }

  /// Mark DM as read
  Future<bool> markDMAsRead(String messageId, String recipientId) async {
    try {
      await _supabase
          .from('direct_messages')
          .update({'is_read': true})
          .eq('id', messageId)
          .eq('recipient_uid', recipientId);

      return true;
    } catch (e) {
      _logger.e('Error marking DM as read: $e');
      return false;
    }
  }

  /// Get unread DM count
  Future<int> getUnreadDMCount(String userId) async {
    try {
      final response = await _supabase
          .from('direct_messages')
          .select()
          .eq('recipient_uid', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      _logger.e('Error getting unread count: $e');
      return 0;
    }
  }

  // ============================================================================
  // MUTED GAMES
  // ============================================================================

  /// Mute a game
  Future<bool> muteGame(
      String userId, String gameSlug, String? gameName) async {
    try {
      await _supabase.from('muted_games').insert({
        'user_uid': userId,
        'game_slug': gameSlug,
        'game_name': gameName,
      });

      _logger.i('Muted game: $gameSlug');
      return true;
    } catch (e) {
      _logger.e('Error muting game: $e');
      return false;
    }
  }

  /// Unmute a game
  Future<bool> unmuteGame(String userId, String gameSlug) async {
    try {
      await _supabase
          .from('muted_games')
          .delete()
          .eq('user_uid', userId)
          .eq('game_slug', gameSlug);

      _logger.i('Unmuted game: $gameSlug');
      return true;
    } catch (e) {
      _logger.e('Error unmuting game: $e');
      return false;
    }
  }

  /// Get muted games list
  Future<List<Map<String, dynamic>>> getMutedGames(String userId) async {
    try {
      final response = await _supabase
          .from('muted_games')
          .select()
          .eq('user_uid', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logger.e('Error getting muted games: $e');
      return [];
    }
  }

  /// Clear all muted games
  Future<bool> clearMutedGames(String userId) async {
    try {
      await _supabase.from('muted_games').delete().eq('user_uid', userId);

      _logger.i('Cleared all muted games for $userId');
      return true;
    } catch (e) {
      _logger.e('Error clearing muted games: $e');
      return false;
    }
  }

  /// Check if game is muted
  Future<bool> isGameMuted(String userId, String gameSlug) async {
    try {
      final response = await _supabase
          .from('muted_games')
          .select()
          .eq('user_uid', userId)
          .eq('game_slug', gameSlug)
          .maybeSingle();

      return response != null;
    } catch (e) {
      _logger.e('Error checking if game muted: $e');
      return false;
    }
  }
}
