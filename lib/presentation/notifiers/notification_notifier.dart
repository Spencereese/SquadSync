import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/notification_priority.dart';
import '../../notification_service.dart';

/// Provider for NotificationNotifier
final notificationNotifierProvider =
    AsyncNotifierProvider<NotificationNotifier, BadgeState>(
  NotificationNotifier.new,
);

/// Skip the shared chat badge only when the open thread matches the payload.
/// Messages with no group column still increment, even if a chat is mounted.
bool shouldSkipChatBadgeIncrement(
  String? activeChatGroupId,
  Object? incomingGroup,
) {
  return incomingGroup != null &&
      incomingGroup.toString() == activeChatGroupId;
}

/// ChatScreen's active thread: widget id, or squad [selectedLobbyId].
/// Never returns an empty string.
String? resolveActiveChatGroupId({
  required String? widgetChatGroupId,
  required bool isSquad,
  String? selectedLobbyId,
}) {
  if (widgetChatGroupId != null && widgetChatGroupId.isNotEmpty) {
    return widgetChatGroupId;
  }
  if (isSquad && selectedLobbyId != null && selectedLobbyId.isNotEmpty) {
    return selectedLobbyId;
  }
  return null;
}

/// First non-null thread id should start ChatNotifier.initializeChat.
bool shouldStartChatInitialization({
  required bool alreadyInitialized,
  required String? nextThreadId,
}) {
  return !alreadyInitialized &&
      nextThreadId != null &&
      nextThreadId.isNotEmpty;
}

/// Why ChatInitializationService stopped before completing.
enum ChatInitBail { none, nullSquad, hardFailure }

/// Re-run after a null-squad wait, or one bounded hard-failure retry.
bool shouldRetryChatInitializationService({
  required bool serviceCompleted,
  required ChatInitBail bail,
  required bool squadStateAvailable,
  required int hardFailureRetries,
  int maxHardFailureRetries = 1,
}) {
  if (serviceCompleted) return false;
  switch (bail) {
    case ChatInitBail.nullSquad:
      return squadStateAvailable;
    case ChatInitBail.hardFailure:
      return hardFailureRetries < maxHardFailureRetries;
    case ChatInitBail.none:
      return false;
  }
}

bool shouldShowInitFailureSnackBar(int hardFailureRetries) =>
    hardFailureRetries == 0;

/// Ignore in-flight init that finished after a lobby switch.
bool shouldCommitInitializationCompletion({
  required String finishingId,
  required int finishingGeneration,
  required String? currentRegisteredId,
  required int currentGeneration,
}) {
  return finishingId == currentRegisteredId &&
      finishingGeneration == currentGeneration;
}

bool shouldRunInitializationService({
  required String requestedId,
  required int requestedGeneration,
  required String? currentRegisteredId,
  required int currentGeneration,
  required bool alreadyCompleted,
}) {
  if (alreadyCompleted) return false;
  return shouldCommitInitializationCompletion(
    finishingId: requestedId,
    finishingGeneration: requestedGeneration,
    currentRegisteredId: currentRegisteredId,
    currentGeneration: currentGeneration,
  );
}

/// Rate-limit delayed re-init must not outrank a newer lobby.
/// When this returns true, ChatScreen replays scheduleChatStart
/// (notifier + ChatInitializationService), not a raw initializeChat.
bool shouldContinueDelayedChatReinit({
  required bool isMounted,
  required String scheduledId,
  required int scheduledGeneration,
  required String? currentRegisteredId,
  required int currentGeneration,
}) {
  if (!isMounted) return false;
  return shouldCommitInitializationCompletion(
    finishingId: scheduledId,
    finishingGeneration: scheduledGeneration,
    currentRegisteredId: currentRegisteredId,
    currentGeneration: currentGeneration,
  );
}

/// One delayed ChannelRateLimitReached replay, then stop.
const kMaxChatRateLimitRetries = 1;

bool shouldScheduleRateLimitRetry(
  int rateLimitRetries, {
  int maxRateLimitRetries = kMaxChatRateLimitRetries,
}) {
  return rateLimitRetries < maxRateLimitRetries;
}

const kRateLimitRetrySnack = 'Too many connections. Cleaning up...';
const kRateLimitGiveUpSnack = 'Too many connections — try again later';

String rateLimitRetrySnackMessage(int rateLimitRetries) {
  return shouldScheduleRateLimitRetry(rateLimitRetries)
      ? kRateLimitRetrySnack
      : kRateLimitGiveUpSnack;
}

bool shouldCleanupPreviousThreadChannels({
  required String? previousId,
  required String? nextId,
}) {
  return previousId != null &&
      previousId.isNotEmpty &&
      nextId != null &&
      nextId != previousId;
}

/// Nuke-all only when every channel topic failed to read.
enum ChannelCleanupMode { scoped, nukeAll }

ChannelCleanupMode channelCleanupMode({
  required int readableTopicCount,
  required int unreadableTopicCount,
}) {
  if (readableTopicCount == 0 && unreadableTopicCount > 0) {
    return ChannelCleanupMode.nukeAll;
  }
  return ChannelCleanupMode.scoped;
}

/// Re-run name/image/settings/draft when the mounted ChatScreen switches thread.
bool shouldRefreshChatInitializationOnNewThread({
  required bool alreadyInitialized,
  required bool isNewId,
}) {
  return alreadyInitialized && isNewId;
}

/// Chat/presence/typing/message topics for [threadId].
/// [topic] may be `realtime:presence:<id>` or `presence:<id>`.
/// Matches the segment after the marker, not a substring of the id.
bool isChatThreadChannelTopic(String topic, String? threadId) {
  final name = topic.toLowerCase().replaceFirst(RegExp(r'^realtime:'), '');
  const colonMarkers = ['presence:', 'typing:', 'messages:'];
  const underscoreMarkers = ['typing_', 'messages_'];
  final isChatTopic = colonMarkers.any(name.startsWith) ||
      underscoreMarkers.any(name.startsWith);
  if (!isChatTopic) return false;
  if (threadId == null || threadId.isEmpty) return true;
  final id = threadId.toLowerCase();
  for (final marker in colonMarkers) {
    if (name == '$marker$id') return true;
  }
  for (final marker in underscoreMarkers) {
    if (name == '$marker$id') return true;
  }
  return false;
}

/// Riverpod notifier for managing notifications with Supabase real-time subscriptions
class NotificationNotifier extends AsyncNotifier<BadgeState> {
  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();

  // Subscriptions for cleanup
  RealtimeChannel? _lobbyChannel;
  RealtimeChannel? _chatChannel;
  StreamSubscription? _presenceSubscription;

  // Momentum tracking
  final Map<String, int> _lobbyPlayerCounts = {};
  final Set<String> _processedMomentumEvents = {};

  /// Chat currently on screen. Incoming messages for this group do not badge.
  String? _activeChatGroupId;

  @override
  Future<BadgeState> build() async {
    // Initialize notification service
    await NotificationService.initialize();

    // Set up real-time subscriptions for momentum detection
    _setupLobbyMomentumSubscription();
    _setupChatBadgeSubscription();

    // Clean up on dispose
    ref.onDispose(() {
      _lobbyChannel?.unsubscribe();
      _chatChannel?.unsubscribe();
      _presenceSubscription?.cancel();
    });

    return _notificationService.getBadgeState();
  }

  /// Set up real-time subscription for lobby momentum detection
  void _setupLobbyMomentumSubscription() {
    _lobbyChannel = _supabase
        .channel('lobby_momentum')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lobby_spots',
          callback: (payload) => _handleLobbyChange(payload),
        )
        .subscribe();
  }

  /// Handle lobby spot changes and detect momentum
  Future<void> _handleLobbyChange(PostgresChangePayload payload) async {
    try {
      final newRecord = payload.newRecord;
      if (newRecord.isEmpty) return;

      final lobbyId = newRecord['lobby_id'] as String?;
      final userId = newRecord['user_id'] as String?;

      if (lobbyId == null || userId == null) return;

      // Fetch full lobby state
      final lobby = await _supabase
          .from('lobbies')
          .select('*, game:games(*)')
          .eq('id', lobbyId)
          .single();

      // Count current players
      final spotsResponse = await _supabase
          .from('lobby_spots')
          .select('id')
          .eq('lobby_id', lobbyId)
          .not('user_id', 'is', null);

      final currentPlayers = (spotsResponse as List).length;
      final previousPlayers = _lobbyPlayerCounts[lobbyId] ?? 0;

      // Momentum detected: player increase
      if (currentPlayers > previousPlayers && currentPlayers > 1) {
        final eventKey = '$lobbyId:$currentPlayers:${DateTime.now().minute}';

        // Cap at one notification per player increase (per minute)
        if (!_processedMomentumEvents.contains(eventKey)) {
          _processedMomentumEvents.add(eventKey);

          // Fetch participant names
          final participants = await _supabase
              .from('lobby_spots')
              .select('user_id, users!inner(display_name)')
              .eq('lobby_id', lobbyId)
              .not('user_id', 'is', null);

          final participantNames = (participants as List)
              .map((p) => p['users']['display_name'] as String? ?? 'Unknown')
              .toList();

          // Get game details
          final gameName = lobby['game']?['name'] as String? ?? 'Unknown Game';
          final maxPlayers = lobby['max_players'] as int? ?? 4;
          final gameImageUrl = lobby['game']?['cover_url'] as String?;

          // Get joiner name
          final joinerName = await _getDisplayName(userId);

          // Send momentum notification
          await _notificationService.sendMomentumNotification(
            lobbyId: lobbyId,
            gameName: gameName,
            currentPlayers: currentPlayers,
            maxPlayers: maxPlayers,
            joinerName: joinerName,
            participantNames: participantNames,
            gameImageUrl: gameImageUrl,
          );

          // Update state
          state = AsyncData(_notificationService.getBadgeState());
        }
      }

      // Update player count tracker
      _lobbyPlayerCounts[lobbyId] = currentPlayers;
    } catch (e) {
      debugPrint('Error handling lobby momentum: $e');
    }
  }

  /// Set up chat badge subscription for unread messages
  void _setupChatBadgeSubscription() {
    _chatChannel = _supabase
        .channel('chat_badges')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) => _handleChatMessage(payload),
        )
        .subscribe();
  }

  /// Handle new chat messages for badge updates
  void _handleChatMessage(PostgresChangePayload payload) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final senderId = payload.newRecord['sender_id'] as String?;

    // Don't badge own messages
    if (senderId == currentUserId) return;

    final incomingGroup = payload.newRecord['chat_group_id'] ??
        payload.newRecord['chat_id'] ??
        payload.newRecord['group_id'];
    if (shouldSkipChatBadgeIncrement(_activeChatGroupId, incomingGroup)) {
      return;
    }

    _notificationService.incrementBadge('chat');
    state = AsyncData(_notificationService.getBadgeState());
  }

  /// ChatScreen registers the open thread so badges do not increment there.
  /// Empty string is treated as no active chat — never register `''`.
  void setActiveChatGroup(String? chatGroupId) {
    final id =
        (chatGroupId == null || chatGroupId.isEmpty) ? null : chatGroupId;
    _activeChatGroupId = id;
    if (id != null) {
      _notificationService.clearBadge('chat');
      state = AsyncData(_notificationService.getBadgeState());
    }
  }

  /// Send direct invite notification
  Future<void> sendDirectInvite({
    required String recipientId,
    required String inviterName,
    required String lobbyId,
    required String gameName,
    String? gameImageUrl,
  }) async {
    await _notificationService.sendDirectInvite(
      recipientId: recipientId,
      inviterName: inviterName,
      lobbyId: lobbyId,
      gameName: gameName,
      gameImageUrl: gameImageUrl,
    );

    state = AsyncData(_notificationService.getBadgeState());
  }

  /// Send spot available notification
  Future<void> sendSpotAvailable({
    required String lobbyId,
    required String gameName,
    required int spotsOpen,
    required List<String> friendsInLobby,
  }) async {
    await _notificationService.sendSpotAvailable(
      lobbyId: lobbyId,
      gameName: gameName,
      spotsOpen: spotsOpen,
      friendsInLobby: friendsInLobby,
    );

    state = AsyncData(_notificationService.getBadgeState());
  }

  /// Clear badge for specific type
  void clearBadge(String type) {
    _notificationService.clearBadge(type);
    state = AsyncData(_notificationService.getBadgeState());
  }

  /// Clear all badges
  void clearAllBadges() {
    _notificationService.clearAllBadges();
    state = AsyncData(_notificationService.getBadgeState());
  }

  /// Get display name for user ID
  Future<String> _getDisplayName(String userId) async {
    try {
      final user = await _supabase
          .from('users')
          .select('display_name')
          .eq('uid', userId)
          .single();
      return user['display_name'] as String? ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
}
