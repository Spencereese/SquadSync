import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../services/auth_service_supabase.dart';

/// Auto-merge detection service for suggesting lobby merges between friends
/// Detects same-game friend lobbies created within 5 minutes and suggests merging
class AutoMergeService {
  static final AutoMergeService _instance = AutoMergeService._internal();
  factory AutoMergeService() => _instance;
  AutoMergeService._internal();

  final _supabase = SupabaseService.client;
  StreamSubscription? _mergeDetectionSubscription;
  final Set<String> _processedMerges = {};

  /// Start listening for merge opportunities
  void startMergeDetection() {
    _mergeDetectionSubscription?.cancel();

    // Listen to new lobbies in real-time
    _mergeDetectionSubscription = _supabase
        .from('lobbies')
        .stream(primaryKey: ['id'])
        .eq('is_public', false) // Only check friend lobbies
        .listen((lobbies) {
          _checkForMergeOpportunities(lobbies);
        });
  }

  /// Stop listening for merge opportunities
  void stopMergeDetection() {
    _mergeDetectionSubscription?.cancel();
    _mergeDetectionSubscription = null;
  }

  /// Check for merge opportunities between friend lobbies
  Future<void> _checkForMergeOpportunities(
      List<Map<String, dynamic>> lobbies) async {
    try {
      final currentUser = AuthServiceSupabase().currentUser;
      if (currentUser == null) return;

      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

      // Get current user's friends
      final friendsResponse = await _supabase
          .from('friends')
          .select('friend_uid')
          .eq('user_uid', currentUser.id)
          .eq('status', 'accepted');

      final friendUids = (friendsResponse as List)
          .map((f) => f['friend_uid'] as String)
          .toSet();

      // Group lobbies by game
      final Map<String, List<Map<String, dynamic>>> lobbiesByGame = {};

      for (final lobby in lobbies) {
        final createdAt = DateTime.parse(lobby['created_at'] as String);

        // Only consider lobbies created within last 5 minutes
        if (createdAt.isBefore(fiveMinutesAgo)) continue;

        final gameName = lobby['game_name'] as String?;
        if (gameName == null) continue;

        lobbiesByGame.putIfAbsent(gameName, () => []);
        lobbiesByGame[gameName]!.add(lobby);
      }

      // Check each game for potential merges
      for (final entry in lobbiesByGame.entries) {
        final gameLobbies = entry.value;

        if (gameLobbies.length < 2) continue;

        // Find pairs of lobbies where:
        // 1. Both have friends as hosts
        // 2. Created within 5 minutes of each other
        // 3. Have matching tags (at least one common tag)
        // 4. Combined spots don't exceed max (e.g., 8)
        for (var i = 0; i < gameLobbies.length; i++) {
          for (var j = i + 1; j < gameLobbies.length; j++) {
            final lobby1 = gameLobbies[i];
            final lobby2 = gameLobbies[j];

            final canMerge = await _canMerge(
              lobby1,
              lobby2,
              friendUids,
              currentUser.id,
            );

            if (canMerge) {
              await _suggestMerge(lobby1, lobby2, currentUser.id);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking merge opportunities: $e');
    }
  }

  /// Check if two lobbies can be merged
  Future<bool> _canMerge(
    Map<String, dynamic> lobby1,
    Map<String, dynamic> lobby2,
    Set<String> friendUids,
    String currentUserId,
  ) async {
    try {
      final lobby1Id = lobby1['id'] as String;
      final lobby2Id = lobby2['id'] as String;

      // Don't reprocess same merge
      final mergeKey = [lobby1Id, lobby2Id]..sort();
      final mergeId = mergeKey.join('-');
      if (_processedMerges.contains(mergeId)) return false;

      // Get member UIDs for both lobbies
      final lobby1Members =
          (lobby1['member_uids'] as List?)?.cast<String>() ?? [];
      final lobby2Members =
          (lobby2['member_uids'] as List?)?.cast<String>() ?? [];

      // Check if current user is in one of the lobbies
      final userInLobby1 = lobby1Members.contains(currentUserId);
      final userInLobby2 = lobby2Members.contains(currentUserId);

      if (!userInLobby1 && !userInLobby2) return false;

      // Check if at least one lobby has a friend as host
      final host1 = lobby1['host_uid'] as String?;
      final host2 = lobby2['host_uid'] as String?;

      final hasFriendHost = (host1 != null && friendUids.contains(host1)) ||
          (host2 != null && friendUids.contains(host2));

      if (!hasFriendHost) return false;

      // Check creation time difference (within 5 minutes)
      final created1 = DateTime.parse(lobby1['created_at'] as String);
      final created2 = DateTime.parse(lobby2['created_at'] as String);
      final timeDiff = created1.difference(created2).abs();

      if (timeDiff.inMinutes > 5) return false;

      // Check tags overlap
      final tags1 =
          Set<String>.from((lobby1['tags'] as List?)?.cast<String>() ?? []);
      final tags2 =
          Set<String>.from((lobby2['tags'] as List?)?.cast<String>() ?? []);
      final commonTags = tags1.intersection(tags2);

      if (commonTags.isEmpty && tags1.isNotEmpty && tags2.isNotEmpty) {
        return false; // No common tags
      }

      // Check combined spots don't exceed max
      final maxSpots1 = lobby1['max_spots'] as int? ?? 4;
      final maxSpots2 = lobby2['max_spots'] as int? ?? 4;
      final currentSpots1 = lobby1Members.length;
      final currentSpots2 = lobby2Members.length;
      final combinedSpots = currentSpots1 + currentSpots2;

      // Allow merge if combined doesn't exceed 8 (or larger max of the two)
      final maxAllowed = maxSpots1 > maxSpots2 ? maxSpots1 : maxSpots2;
      if (combinedSpots > maxAllowed && combinedSpots > 8) return false;

      return true;
    } catch (e) {
      debugPrint('Error in canMerge: $e');
      return false;
    }
  }

  /// Suggest a merge via notification
  Future<void> _suggestMerge(
    Map<String, dynamic> lobby1,
    Map<String, dynamic> lobby2,
    String currentUserId,
  ) async {
    try {
      final lobby1Id = lobby1['id'] as String;
      final lobby2Id = lobby2['id'] as String;

      // Mark as processed
      final mergeKey = [lobby1Id, lobby2Id]..sort();
      final mergeId = mergeKey.join('-');
      _processedMerges.add(mergeId);

      // Determine which lobby the user is in
      final lobby1Members =
          (lobby1['member_uids'] as List?)?.cast<String>() ?? [];
      final lobby2Members =
          (lobby2['member_uids'] as List?)?.cast<String>() ?? [];
      final userInLobby1 = lobby1Members.contains(currentUserId);

      final userLobbyId = userInLobby1 ? lobby1Id : lobby2Id;
      final otherLobbyId = userInLobby1 ? lobby2Id : lobby1Id;
      final otherLobby = userInLobby1 ? lobby2 : lobby1;
      final otherLobbyName = otherLobby['name'] as String?;
      final otherHost = otherLobby['host_uid'] as String?;

      // Get friend's display name
      String friendName = 'Unknown';
      if (otherHost != null) {
        final userResponse = await _supabase
            .from('users')
            .select('display_name')
            .eq('uid', otherHost)
            .maybeSingle();

        if (userResponse != null) {
          friendName = userResponse['display_name'] ?? 'Unknown';
        }
      }

      // Calculate combined spots
      final combinedSpots = lobby1Members.length + lobby2Members.length;

      // Create merge suggestion notification
      await _supabase.from('notifications').insert({
        'user_uid': currentUserId,
        'type': 'lobby_merge_suggestion',
        'title': 'Merge Lobbies?',
        'body':
            'Merge with $friendName\'s lobby "${otherLobbyName ?? "Lobby"}"? Spots to $combinedSpots',
        'data': {
          'merge_from_lobby_id': userLobbyId,
          'merge_to_lobby_id': otherLobbyId,
          'merge_id': mergeId,
          'friend_name': friendName,
          'combined_spots': combinedSpots,
        },
        'created_at': DateTime.now().toIso8601String(),
        'read': false,
      });

      debugPrint('🔗 Merge suggestion created: $userLobbyId + $otherLobbyId');
    } catch (e) {
      debugPrint('Error suggesting merge: $e');
    }
  }

  /// Execute a lobby merge (called when user approves)
  Future<void> executeMerge(
    String fromLobbyId,
    String toLobbyId,
  ) async {
    try {
      // Get both lobbies
      final fromLobby = await _supabase
          .from('lobbies')
          .select()
          .eq('id', fromLobbyId)
          .single();

      final toLobby =
          await _supabase.from('lobbies').select().eq('id', toLobbyId).single();

      // Combine member lists
      final fromMembers = Set<String>.from(
        (fromLobby['member_uids'] as List?)?.cast<String>() ?? [],
      );
      final toMembers = Set<String>.from(
        (toLobby['member_uids'] as List?)?.cast<String>() ?? [],
      );
      final combinedMembers = {...fromMembers, ...toMembers}.toList();

      // Update target lobby with combined members
      await _supabase.from('lobbies').update({
        'member_uids': combinedMembers,
        'max_spots': combinedMembers.length > 4 ? 8 : 4, // Adjust max spots
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', toLobbyId);

      // Delete source lobby
      await _supabase.from('lobbies').delete().eq('id', fromLobbyId);

      // Notify all members of successful merge
      for (final memberUid in fromMembers) {
        await _supabase.from('notifications').insert({
          'user_uid': memberUid,
          'type': 'lobby_merged',
          'title': 'Lobby Merged!',
          'body': 'Your lobby has been merged. Check it out!',
          'data': {'new_lobby_id': toLobbyId},
          'created_at': DateTime.now().toIso8601String(),
          'read': false,
        });
      }

      debugPrint('✅ Lobbies merged successfully: $fromLobbyId → $toLobbyId');
    } catch (e) {
      debugPrint('Error executing merge: $e');
      rethrow;
    }
  }

  /// Dismiss a merge suggestion
  void dismissMergeSuggestion(String mergeId) {
    _processedMerges.add(mergeId);
    debugPrint('❌ Merge suggestion dismissed: $mergeId');
  }
}
