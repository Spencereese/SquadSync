import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../managers/notification_manager.dart';
import '../notification_service.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import 'peacock_assignment_machine.dart';
import 'preferred_peacock_games.dart';

export 'peacock_self_notify.dart';

/// Assignment-id dedup. Caps size and drops entries older than [ttl] so a
/// long-lived process cannot grow unbounded.
class PeacockIdCache {
  PeacockIdCache({
    this.maxSize = defaultMaxSize,
    this.ttl = defaultTtl,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const int defaultMaxSize = 256;
  static const Duration defaultTtl = Duration(hours: 6);

  final int maxSize;
  final Duration ttl;
  final DateTime Function() _clock;
  final Map<String, DateTime> _entries = <String, DateTime>{};

  bool contains(String id) {
    prune();
    return _entries.containsKey(id);
  }

  void add(String id) {
    prune();
    _entries.remove(id);
    _entries[id] = _clock();
    while (_entries.length > maxSize) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();

  Set<String> toSet() {
    prune();
    return _entries.keys.toSet();
  }

  @visibleForTesting
  int get length => _entries.length;

  void prune() {
    final cutoff = _clock().subtract(ttl);
    _entries.removeWhere((_, stamped) => !stamped.isAfter(cutoff));
  }
}

/// Service for listening to peacock queue assignment notifications
///
/// Subscribes to Realtime updates on peacock_notifications table
/// and sends FCM push notifications when users are auto-assigned spots
class PeacockNotificationService {
  static RealtimeChannel? _channel;
  static final PeacockIdCache _handledIds = PeacockIdCache();
  static final PeacockIdCache _locallyPresentedIds = PeacockIdCache();

  /// Test hook. Production uses [AuthServiceSupabase.currentUser].
  @visibleForTesting
  static String? Function()? currentUidHook;

  /// Test hook. Production uses [WidgetsBinding] lifecycle.
  @visibleForTesting
  static bool Function()? isForegroundHook;

  /// Test hook. Production sends via [NotificationService.sendNotificationToUsers].
  @visibleForTesting
  static Future<void> Function({
    required String title,
    required String body,
    required List<String> recipientUids,
    Map<String, dynamic>? data,
  })? sendToUsersHook;

  /// Test hook. Production marks `peacock_notifications.sent = true`.
  @visibleForTesting
  static Future<void> Function(String notificationId)? markSentHook;

  @visibleForTesting
  static void resetTestHooks() {
    currentUidHook = null;
    isForegroundHook = null;
    sendToUsersHook = null;
    markSentHook = null;
    _handledIds.clear();
    _locallyPresentedIds.clear();
    PeacockAssignmentTracker.instance.clear();
    PreferredPeacockGamesStore.instance.reset();
  }

  /// Start listening for peacock queue notifications
  static Future<void> initialize() async {
    final session = await SupabaseService.ensureFreshSession();
    final user = session?.user;
    if (user == null) {
      developer.log(
          'Cannot initialize peacock notifications - user not authenticated');
      return;
    }

    await PreferredPeacockGamesStore.instance.load();
    developer.log(
        '🦚 Initializing peacock notification listener for user ${user.id}');

    // Subscribe to peacock_notifications table for current user
    _channel = SupabaseService.client
        .channel('peacock_notifications_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'peacock_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_uid',
            value: user.id,
          ),
          callback: (payload) async {
            developer
                .log('🎮 Peacock notification received: ${payload.newRecord}');
            await handleNotification(payload.newRecord);
          },
        )
        .subscribe();

    developer.log('✅ Peacock notification listener active');
  }

  /// Handle incoming notification.
  ///
  /// Local for in-app Realtime, FCM only when backgrounded — never both
  /// to the current uid for the same event_id. Always marks `sent: true`.
  @visibleForTesting
  static Future<void> handleNotification(Map<String, dynamic> record) async {
    try {
      final title = record['title'] as String? ?? '🎮 Spot Available';
      final body = record['body'] as String? ?? 'Your spot is ready!';
      final rawData = record['data'];
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      final eventId = peacockEventId(record);
      if (eventId == null) return;
      final rowId = _nonEmpty(record['id']) ?? eventId;
      final type = _nonEmpty(data['type']) ?? 'peacock_assigned';
      final lobbyId = _nonEmpty(data['lobby_id']) ?? _nonEmpty(data['lobbyId']);
      final gameName =
          _nonEmpty(data['game_name']) ?? _nonEmpty(data['gameName']);
      final spotIndex = _nonEmpty(data['spot_index']);
      final parsedSpot = spotIndex == null ? null : int.tryParse(spotIndex);

      final duplicate = _handledIds.contains(eventId);
      _handledIds.add(eventId);
      if (duplicate) {
        await _markSent(rowId);
        return;
      }

      final currentUid =
          currentUidHook?.call() ?? AuthServiceSupabase().currentUser?.id;
      if (!peacockEventIsForCurrentUid(
        record: record,
        currentUid: currentUid,
      )) {
        await _markSent(rowId);
        return;
      }
      final isForeground = _isForeground();
      final trackerUserId = currentUid ?? peacockRecordUid(record) ?? eventId;

      // Realtime insert is this client's assign event when the host
      // processed the queue elsewhere. Then notifySelf — XOR via the
      // reducer (planPeacockSelfNotify), never a parallel plan.
      final tracker = PeacockAssignmentTracker.instance;
      tracker.assignSpot(
        trackerUserId,
        lobbyId: lobbyId,
        gameName: gameName,
        notificationId: eventId,
        spotIndex: parsedSpot != null && parsedSpot >= 0 ? parsedSpot : null,
      );
      if (!peacockOfferAllowed(
        gameName: gameName,
        preferredPeacockGames: PreferredPeacockGamesStore.instance.snapshot,
      )) {
        await _markSent(rowId);
        return;
      }
      final dispatch = tracker.notifySelf(
        trackerUserId,
        isForeground: isForeground,
        currentUid: currentUid,
        notificationId: eventId,
      );
      final plan = dispatch.plan;
      final fcmUids = peacockSelfUidRecipients(
        candidateUids: plan.recipientUids,
        currentUid: currentUid,
        showLocal: plan.showLocal,
      );

      if (plan.showLocal) {
        developer.log('📣 Showing notification: $title - $body');
        await NotificationManager().showNotification(
          title: title,
          body: body,
          type: type,
          lobbyId: lobbyId,
          gameName: gameName,
          payload: {
            'event_id': eventId,
            if (spotIndex != null) 'spot_index': spotIndex,
          },
        );
        _locallyPresentedIds.add(eventId);
      }

      // Never FCM to self if this assignment was (or just was) shown locally.
      if (plan.sendFcmToSelf &&
          !plan.showLocal &&
          !_locallyPresentedIds.contains(eventId) &&
          fcmUids.isNotEmpty) {
        final send =
            sendToUsersHook ?? NotificationService.sendNotificationToUsers;
        await send(
          title: title,
          body: body,
          recipientUids: fcmUids,
          data: {
            'type': type,
            'event_id': eventId,
            if (lobbyId != null) 'lobby_id': lobbyId,
            if (gameName != null) 'game_name': gameName,
            if (spotIndex != null) 'spot_index': spotIndex,
          },
        );
      }

      await _markSent(rowId);

      developer.log('✅ Notification handled and marked as delivered');
    } catch (e) {
      developer.log('❌ Error handling peacock notification: $e');
    }
  }

  static Future<void> _markSent(String notificationId) async {
    final hook = markSentHook;
    if (hook != null) {
      await hook(notificationId);
      return;
    }
    await SupabaseService.client.from('peacock_notifications').update({
      'sent': true,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', notificationId);
  }

  static bool _isForeground() {
    final hook = isForegroundHook;
    if (hook != null) return hook();
    try {
      return peacockLifecycleIsForeground(
        WidgetsBinding.instance.lifecycleState,
      );
    } catch (_) {
      // No binding (plain unit tests) — Realtime path is in-app.
      return true;
    }
  }

  /// Stop listening for notifications. Clears id caches (logout / app dispose).
  static Future<void> dispose() async {
    try {
      if (_channel != null) {
        developer.log('🦚 Disposing peacock notification listener');
        await SupabaseService.client.removeChannel(_channel!);
      }
    } finally {
      _channel = null;
      _handledIds.clear();
      _locallyPresentedIds.clear();
      PeacockAssignmentTracker.instance.clear();
    }
  }

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  /// Fetch pending notifications on app startup
  static Future<void> checkPendingNotifications() async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) return;

    try {
      // Get unsent notifications from last 6 hours
      final sixHoursAgo = DateTime.now().subtract(const Duration(hours: 6));
      final response = await SupabaseService.client
          .from('peacock_notifications')
          .select()
          .eq('user_uid', user.id)
          .eq('sent', false)
          .gte('created_at', sixHoursAgo.toIso8601String())
          .order('created_at', ascending: true);

      if (response.isNotEmpty) {
        developer
            .log('📬 Found ${response.length} pending peacock notifications');

        for (final notification in response) {
          await handleNotification(notification);

          // Small delay between notifications
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      developer.log('❌ Error checking pending notifications: $e');
    }
  }
}
