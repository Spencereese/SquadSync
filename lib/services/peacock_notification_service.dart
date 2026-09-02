import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../managers/notification_manager.dart';
import '../notification_service.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';

/// Local XOR FCM-to-self for one peacock assignment.
class PeacockSelfNotifyPlan {
  const PeacockSelfNotifyPlan({
    required this.showLocal,
    required this.sendFcmToSelf,
    required this.recipientUids,
  });

  final bool showLocal;
  final bool sendFcmToSelf;
  final List<String> recipientUids;

  /// True if this plan would both present locally and FCM the same uid.
  bool get wouldDoubleNotifySelf =>
      showLocal && sendFcmToSelf && recipientUids.isNotEmpty;
}

/// One alert per assignment: in-app Realtime shows local; FCM only when
/// backgrounded and that [notificationId] was not already presented locally.
PeacockSelfNotifyPlan planPeacockSelfNotify({
  required String notificationId,
  required String? currentUid,
  required bool isForeground,
  required Set<String> locallyPresentedIds,
}) {
  if (locallyPresentedIds.contains(notificationId)) {
    return const PeacockSelfNotifyPlan(
      showLocal: false,
      sendFcmToSelf: false,
      recipientUids: [],
    );
  }
  if (isForeground) {
    return const PeacockSelfNotifyPlan(
      showLocal: true,
      sendFcmToSelf: false,
      recipientUids: [],
    );
  }
  final uid = currentUid;
  if (uid == null || uid.isEmpty) {
    return const PeacockSelfNotifyPlan(
      showLocal: false,
      sendFcmToSelf: false,
      recipientUids: [],
    );
  }
  return PeacockSelfNotifyPlan(
    showLocal: false,
    sendFcmToSelf: true,
    recipientUids: [uid],
  );
}

/// Service for listening to peacock queue assignment notifications
///
/// Subscribes to Realtime updates on peacock_notifications table
/// and sends FCM push notifications when users are auto-assigned spots
class PeacockNotificationService {
  static RealtimeChannel? _channel;
  static final Set<String> _handledIds = <String>{};
  static final Set<String> _locallyPresentedIds = <String>{};

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
  /// to the current uid for the same [record] id. Always marks `sent: true`.
  @visibleForTesting
  static Future<void> handleNotification(Map<String, dynamic> record) async {
    try {
      final title = record['title'] as String? ?? '🎮 Spot Available';
      final body = record['body'] as String? ?? 'Your spot is ready!';
      final rawData = record['data'];
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      final notificationId = record['id'] as String;
      final type = _nonEmpty(data['type']) ?? 'peacock_assigned';
      final lobbyId = _nonEmpty(data['lobby_id']) ?? _nonEmpty(data['lobbyId']);
      final gameName =
          _nonEmpty(data['game_name']) ?? _nonEmpty(data['gameName']);
      final spotIndex = _nonEmpty(data['spot_index']) ?? '0';

      final duplicate = _handledIds.contains(notificationId);
      _handledIds.add(notificationId);
      if (duplicate) {
        await _markSent(notificationId);
        return;
      }

      final currentUid =
          currentUidHook?.call() ?? AuthServiceSupabase().currentUser?.id;
      final plan = planPeacockSelfNotify(
        notificationId: notificationId,
        currentUid: currentUid,
        isForeground: _isForeground(),
        locallyPresentedIds: _locallyPresentedIds,
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
            'spot_index': spotIndex,
          },
        );
        _locallyPresentedIds.add(notificationId);
      }

      // Never FCM to self if this assignment was (or just was) shown locally.
      if (plan.sendFcmToSelf &&
          !plan.showLocal &&
          !_locallyPresentedIds.contains(notificationId) &&
          plan.recipientUids.isNotEmpty) {
        final send =
            sendToUsersHook ?? NotificationService.sendNotificationToUsers;
        await send(
          title: title,
          body: body,
          recipientUids: plan.recipientUids,
          data: {
            'type': type,
            if (lobbyId != null) 'lobby_id': lobbyId,
            if (gameName != null) 'game_name': gameName,
            'spot_index': spotIndex,
          },
        );
      }

      await _markSent(notificationId);

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
      final state = WidgetsBinding.instance.lifecycleState;
      return state == null || state == AppLifecycleState.resumed;
    } catch (_) {
      // No binding (plain unit tests) — Realtime path is in-app.
      return true;
    }
  }

  /// Stop listening for notifications
  static Future<void> dispose() async {
    if (_channel != null) {
      developer.log('🦚 Disposing peacock notification listener');
      await SupabaseService.client.removeChannel(_channel!);
      _channel = null;
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
