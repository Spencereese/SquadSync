import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../notifiers/notification_notifier.dart';

/// Extension to LobbyNotifier for notification integration
/// Add these methods to your existing LobbyNotifier class
mixin NotificationIntegrationMixin {
  final _supabase = Supabase.instance.client;

  /// Send momentum notification when lobby fills up
  /// Call this after a user successfully claims a spot
  Future<void> sendLobbyMomentumNotification({
    required String lobbyId,
    required String gameName,
    required int currentPlayers,
    required int maxPlayers,
    required String joinerName,
    required WidgetRef ref,
  }) async {
    // Only send momentum alerts when lobby is filling (2+ players)
    if (currentPlayers < 2) return;

    // Fetch current participants
    final participants = await _supabase
        .from('lobby_spots')
        .select('user_id, users!inner(display_name)')
        .eq('lobby_id', lobbyId)
        .not('user_id', 'is', null);

    final participantNames = (participants as List)
        .map((p) => p['users']['display_name'] as String? ?? 'Unknown')
        .toList();

    // Fetch game details
    final lobby = await _supabase
        .from('lobbies')
        .select('game:games(cover_url)')
        .eq('id', lobbyId)
        .single();

    final gameImageUrl = lobby['game']?['cover_url'] as String?;

    // Send momentum notification via NotificationNotifier
    final notifier = ref.read(notificationNotifierProvider.notifier);
    await notifier.sendMomentumNotification(
      lobbyId: lobbyId,
      gameName: gameName,
      currentPlayers: currentPlayers,
      maxPlayers: maxPlayers,
      joinerName: joinerName,
      participantNames: participantNames,
      gameImageUrl: gameImageUrl,
    );
  }

  /// Send direct invite when inviting a user to lobby
  /// Call this from your invite function
  Future<void> sendLobbyInviteNotification({
    required String recipientId,
    required String lobbyId,
    required String gameName,
    required String inviterName,
    required WidgetRef ref,
  }) async {
    // Fetch game cover for rich notification
    final game = await _supabase
        .from('games')
        .select('cover_url')
        .eq('name', gameName)
        .maybeSingle();

    final gameImageUrl = game?['cover_url'] as String?;

    // Send invite notification
    final notifier = ref.read(notificationNotifierProvider.notifier);
    await notifier.sendDirectInvite(
      recipientId: recipientId,
      inviterName: inviterName,
      lobbyId: lobbyId,
      gameName: gameName,
      gameImageUrl: gameImageUrl,
    );
  }

  /// Send spot available notification when someone leaves
  /// Call this after a user releases their spot
  Future<void> sendSpotAvailableNotification({
    required String lobbyId,
    required String gameName,
    required int spotsOpen,
    required WidgetRef ref,
  }) async {
    // Fetch friends in lobby for personalization
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final friends = await _supabase.rpc(
      'get_friends_in_lobby',
      params: {
        'p_user_id': currentUserId,
        'p_lobby_id': lobbyId,
      },
    );

    final friendsInLobby = (friends as List)
        .map((f) => f['display_name'] as String? ?? 'Unknown')
        .toList();

    // Send spot available notification
    final notifier = ref.read(notificationNotifierProvider.notifier);
    await notifier.sendSpotAvailable(
      lobbyId: lobbyId,
      gameName: gameName,
      spotsOpen: spotsOpen,
      friendsInLobby: friendsInLobby,
    );
  }
}

/// Example: Enhanced LobbyNotifier with notification integration
/// Replace your existing claimSpot method with this enhanced version
class EnhancedLobbyNotifierExample {
  Future<void> claimSpot({
    required String lobbyId,
    required int spotIndex,
    required String gameName,
    required WidgetRef ref,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Claim the spot (existing logic)
      await supabase.from('lobby_spots').update({
        'user_id': userId,
        'claimed_at': DateTime.now().toIso8601String(),
        'expires_at':
            DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
      }).match({
        'lobby_id': lobbyId,
        'spot_index': spotIndex,
      });

      // Fetch updated lobby state
      final lobby = await supabase
          .from('lobbies')
          .select('max_players')
          .eq('id', lobbyId)
          .single();

      final spotsResponse = await supabase
          .from('lobby_spots')
          .select('id')
          .eq('lobby_id', lobbyId)
          .not('user_id', 'is', null);

      final currentPlayers = (spotsResponse as List).length;
      final maxPlayers = lobby['max_players'] as int;

      // Get joiner display name
      final user = await supabase
          .from('users')
          .select('display_name')
          .eq('id', userId)
          .single();

      final joinerName = user['display_name'] as String? ?? 'Unknown';

      // 🔥 NEW: Send momentum notification
      await _sendLobbyMomentumNotification(
        lobbyId: lobbyId,
        gameName: gameName,
        currentPlayers: currentPlayers,
        maxPlayers: maxPlayers,
        joinerName: joinerName,
        ref: ref,
      );

      // 🎭 NEW: Start iOS Live Activity if in favorite group
      await _startLiveActivityIfFavorite(
        lobbyId: lobbyId,
        gameName: gameName,
        currentPlayers: currentPlayers,
        maxPlayers: maxPlayers,
        ref: ref,
      );
    } catch (e) {
      print('❌ Error claiming spot: $e');
      rethrow;
    }
  }

  Future<void> _sendLobbyMomentumNotification({
    required String lobbyId,
    required String gameName,
    required int currentPlayers,
    required int maxPlayers,
    required String joinerName,
    required WidgetRef ref,
  }) async {
    final supabase = Supabase.instance.client;

    // Fetch participants
    final participants = await supabase
        .from('lobby_spots')
        .select('user_id, users!inner(display_name)')
        .eq('lobby_id', lobbyId)
        .not('user_id', 'is', null);

    final participantNames = (participants as List)
        .map((p) => p['users']['display_name'] as String? ?? 'Unknown')
        .toList();

    // Fetch game cover
    final lobby = await supabase
        .from('lobbies')
        .select('game:games(cover_url)')
        .eq('id', lobbyId)
        .single();

    final gameImageUrl = lobby['game']?['cover_url'] as String?;

    // Send notification
    final notifier = ref.read(notificationNotifierProvider.notifier);
    await notifier.sendMomentumNotification(
      lobbyId: lobbyId,
      gameName: gameName,
      currentPlayers: currentPlayers,
      maxPlayers: maxPlayers,
      joinerName: joinerName,
      participantNames: participantNames,
      gameImageUrl: gameImageUrl,
    );
  }

  Future<void> _startLiveActivityIfFavorite({
    required String lobbyId,
    required String gameName,
    required int currentPlayers,
    required int maxPlayers,
    required WidgetRef ref,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Check if lobby group is in user's favorites
      final user = await supabase
          .from('users')
          .select('favorite_groups')
          .eq('id', userId)
          .single();

      final favoriteGroups = user['favorite_groups'] as List? ?? [];

      // Get lobby's group
      final lobby = await supabase
          .from('lobbies')
          .select('group_id')
          .eq('id', lobbyId)
          .single();

      final groupId = lobby['group_id'] as String?;

      if (groupId == null || !favoriteGroups.contains(groupId)) return;

      // Start Live Activity for favorite group
      final liveActivityManager = LiveActivityManager();
      final isSupported = await liveActivityManager.isSupported();

      if (!isSupported) return;

      final participants = await supabase
          .from('lobby_spots')
          .select('users!inner(display_name)')
          .eq('lobby_id', lobbyId)
          .not('user_id', 'is', null);

      final participantNames = (participants as List)
          .map((p) => p['users']['display_name'] as String? ?? 'Unknown')
          .toList();

      await liveActivityManager.startLobbyActivity(
        lobbyId: lobbyId,
        gameName: gameName,
        currentPlayers: currentPlayers,
        maxPlayers: maxPlayers,
        participantNames: participantNames,
      );
    } catch (e) {
      print('⚠️ Failed to start Live Activity: $e');
    }
  }
}

/// Example: Add to your invite function
class InviteIntegrationExample {
  Future<void> inviteUserToLobby({
    required String recipientId,
    required String lobbyId,
    required String gameName,
    required WidgetRef ref,
  }) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');

    // Get current user display name
    final user = await supabase
        .from('users')
        .select('display_name')
        .eq('id', currentUser.id)
        .single();

    final inviterName = user['display_name'] as String? ?? 'Unknown';

    // Create invite record (your existing logic)
    await supabase.from('lobby_invites').insert({
      'lobby_id': lobbyId,
      'inviter_id': currentUser.id,
      'recipient_id': recipientId,
      'status': 'pending',
    });

    // 🔥 NEW: Send push notification
    final notifier = ref.read(notificationNotifierProvider.notifier);
    await notifier.sendDirectInvite(
      recipientId: recipientId,
      inviterName: inviterName,
      lobbyId: lobbyId,
      gameName: gameName,
    );
  }
}

/// Example: Add favorite groups management
class FavoriteGroupsManager {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Add group to favorites (enables Live Activities)
  Future<void> addFavoriteGroup(String groupId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final user = await _supabase
        .from('users')
        .select('favorite_groups')
        .eq('id', userId)
        .single();

    final favoriteGroups = List<String>.from(user['favorite_groups'] ?? []);

    if (!favoriteGroups.contains(groupId)) {
      favoriteGroups.add(groupId);

      await _supabase.from('users').update({
        'favorite_groups': favoriteGroups,
      }).eq('id', userId);
    }
  }

  /// Remove group from favorites
  Future<void> removeFavoriteGroup(String groupId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final user = await _supabase
        .from('users')
        .select('favorite_groups')
        .eq('id', userId)
        .single();

    final favoriteGroups = List<String>.from(user['favorite_groups'] ?? []);
    favoriteGroups.remove(groupId);

    await _supabase.from('users').update({
      'favorite_groups': favoriteGroups,
    }).eq('id', userId);
  }

  /// Check if group is favorite
  Future<bool> isFavoriteGroup(String groupId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final user = await _supabase
        .from('users')
        .select('favorite_groups')
        .eq('id', userId)
        .single();

    final favoriteGroups = user['favorite_groups'] as List? ?? [];
    return favoriteGroups.contains(groupId);
  }
}
