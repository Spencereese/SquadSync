import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../notification_service.dart';
import '../services/auth_service_supabase.dart';

/// Service for listening to peacock queue assignment notifications
///
/// Subscribes to Realtime updates on peacock_notifications table
/// and sends FCM push notifications when users are auto-assigned spots
class PeacockNotificationService {
  static RealtimeChannel? _channel;

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
            await _handleNotification(payload.newRecord);
          },
        )
        .subscribe();

    developer.log('✅ Peacock notification listener active');
  }

  /// Handle incoming notification
  static Future<void> _handleNotification(Map<String, dynamic> record) async {
    try {
      final title = record['title'] as String? ?? '🎮 Spot Available';
      final body = record['body'] as String? ?? 'Your spot is ready!';
      final data = record['data'] as Map<String, dynamic>? ?? {};
      final notificationId = record['id'] as String;

      developer.log('📣 Showing notification: $title - $body');

      // Send local notification via Firebase Messaging
      // This will display even if app is in background/foreground
      final user = AuthServiceSupabase().currentUser;
      if (user != null) {
        await NotificationService.sendNotificationToUsers(
          title: title,
          body: body,
          recipientUids: [user.id],
          data: {
            'type': data['type']?.toString() ?? 'peacock_assigned',
            'lobby_id': data['lobby_id']?.toString() ?? '',
            'game_name': data['game_name']?.toString() ?? '',
            'spot_index': data['spot_index']?.toString() ?? '0',
          },
        );
      }

      // Mark notification as sent
      await SupabaseService.client.from('peacock_notifications').update({
        'sent': true,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', notificationId);

      developer.log('✅ Notification sent and marked as delivered');
    } catch (e) {
      developer.log('❌ Error handling peacock notification: $e');
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
          await _handleNotification(notification);

          // Small delay between notifications
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      developer.log('❌ Error checking pending notifications: $e');
    }
  }
}
