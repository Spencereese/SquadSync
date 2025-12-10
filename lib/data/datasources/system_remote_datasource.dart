import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:squad_sync/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service_supabase.dart';

abstract class SystemRemoteDataSource {
  Future<List<Map<String, dynamic>>> getNotifications(String userId);
  Future<List<Map<String, dynamic>>> getAvailabilitySlots(String userId);
  Future<Map<String, Map<String, bool>>> getDailyBanVotes();
  Future<List<Map<String, dynamic>>> getBans(String userId);
  Future<void> addNotification(
      String userId, Map<String, dynamic> notification);
  Future<void> markNotificationsAsRead(String userId);
  Future<void> deleteNotification(String notificationId);
  Future<void> addAvailabilitySlot(String userId, Map<String, dynamic> slot);
  Future<void> removeAvailabilitySlot(String slotId);
  Future<void> updateAvailabilitySlot(
      String slotId, Map<String, dynamic> updates);
  Future<void> submitBanVote(String voterId, String targetUserId, bool vote);
  Future<void> sendAnalyticsEvent(String event, Map<String, dynamic> data);
  Future<Map<String, dynamic>> getAnalyticsMetrics();
  Future<void> sendLocalNotification(String title, String body,
      {Map<String, dynamic>? data});
  Future<void> scheduleLocalNotification(
      DateTime scheduledTime, String title, String body,
      {Map<String, dynamic>? data});
  Future<void> clearOldNotifications({Duration? olderThan});
  Future<void> resetDailyVotes();
  Future<void> purgeOldData({Duration? olderThan});
  Future<void> banUser(String userId, String reason);
  Future<void> unbanUser(String userId);
  Future<bool> checkAvailability();
}

class SystemRemoteDataSourceImpl implements SystemRemoteDataSource {
  final Logger _logger = Logger();
  final AuthServiceSupabase _authService = AuthServiceSupabase();
  final SupabaseClient _supabase = SupabaseService.client;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final http.Client _httpClient;
  final String? _analyticsEndpoint;

  SystemRemoteDataSourceImpl(
    this._localNotifications,
    this._httpClient,
    this._analyticsEndpoint,
  );

  @override
  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailabilitySlots(String userId) async {
    final response = await _supabase
        .from('availability_slots')
        .select()
        .eq('user_id', userId);

    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<Map<String, Map<String, bool>>> getDailyBanVotes() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final response =
        await _supabase.from('ban_votes').select().eq('date', today);

    final dailyBanVotes = <String, Map<String, bool>>{};
    for (var data in response as List) {
      final voterId = data['voter_id'] as String;
      final targetId = data['target_id'] as String;
      final vote = data['vote'] as bool;

      dailyBanVotes.putIfAbsent(voterId, () => {})[targetId] = vote;
    }

    return dailyBanVotes;
  }

  @override
  Future<List<Map<String, dynamic>>> getBans(String userId) async {
    final response =
        await _supabase.from('bans').select().eq('user_id', userId);

    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<void> addNotification(
      String userId, Map<String, dynamic> notification) async {
    await _supabase.from('notifications').insert({
      ...notification,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'user_id': userId,
      'timestamp': DateTime.now().toIso8601String(),
      'read': false,
    });
  }

  @override
  Future<void> markNotificationsAsRead(String userId) async {
    await _supabase
        .from('notifications')
        .update({'read': true})
        .eq('user_id', userId)
        .eq('read', false);
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await _supabase.from('notifications').delete().eq('id', notificationId);
  }

  @override
  Future<void> addAvailabilitySlot(
      String userId, Map<String, dynamic> slot) async {
    await _supabase.from('availability_slots').insert({
      ...slot,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'user_id': userId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> removeAvailabilitySlot(String slotId) async {
    await _supabase.from('availability_slots').delete().eq('id', slotId);
  }

  @override
  Future<void> updateAvailabilitySlot(
      String slotId, Map<String, dynamic> updates) async {
    await _supabase.from('availability_slots').update(updates).eq('id', slotId);
  }

  @override
  Future<void> submitBanVote(
      String voterId, String targetUserId, bool vote) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _supabase.from('ban_votes').insert({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'voter_id': voterId,
      'target_id': targetUserId,
      'vote': vote,
      'date': today,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> sendAnalyticsEvent(
      String event, Map<String, dynamic> data) async {
    if (_analyticsEndpoint == null) {
      // If no HTTP endpoint, use Supabase analytics table
      final userId = _authService.currentUserId;
      await _supabase.from('analytics').insert({
        'user_id': userId,
        'event': event,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return;
    }

    try {
      await _httpClient.post(
        Uri.parse(_analyticsEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'event': event,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      // Analytics failure shouldn't crash the app
      _logger.e('Analytics error: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getAnalyticsMetrics() async {
    // This would fetch aggregated metrics from PostgreSQL
    // Using Supabase RPC functions for complex queries
    try {
      final response = await _supabase.rpc('get_analytics_metrics');
      return response as Map<String, dynamic>;
    } catch (e) {
      _logger.w('Analytics metrics not available: $e');
      return {};
    }
  }

  @override
  Future<void> sendLocalNotification(String title, String body,
      {Map<String, dynamic>? data}) async {
    const androidDetails = AndroidNotificationDetails(
      'system_channel',
      'System Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  @override
  Future<void> scheduleLocalNotification(
      DateTime scheduledTime, String title, String body,
      {Map<String, dynamic>? data}) async {
    const androidDetails = AndroidNotificationDetails(
      'scheduled_channel',
      'Scheduled Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  @override
  Future<void> clearOldNotifications({Duration? olderThan}) async {
    final cutoff =
        DateTime.now().subtract(olderThan ?? const Duration(days: 30));

    await _supabase
        .from('notifications')
        .delete()
        .filter('timestamp', 'lt', cutoff.toIso8601String());
  }

  @override
  Future<void> resetDailyVotes() async {
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')[0];

    await _supabase.from('ban_votes').delete().filter('date', 'lt', yesterday);
  }

  @override
  Future<void> purgeOldData({Duration? olderThan}) async {
    final cutoff =
        DateTime.now().subtract(olderThan ?? const Duration(days: 30));

    // Purge old notifications
    await clearOldNotifications(olderThan: olderThan);

    // Purge old availability slots
    await _supabase
        .from('availability_slots')
        .delete()
        .filter('timestamp', 'lt', cutoff.toIso8601String());

    // Purge old ban votes
    await resetDailyVotes();
  }

  @override
  Future<void> banUser(String userId, String reason) async {
    await _supabase.from('bans').insert({
      'id': userId, // Use user_id as primary key for unique constraint
      'user_id': userId,
      'reason': reason,
      'banned_at': DateTime.now().toIso8601String(),
      'banned_by': _authService.currentUserId,
    });
  }

  @override
  Future<void> unbanUser(String userId) async {
    await _supabase.from('bans').delete().eq('user_id', userId);
  }

  @override
  Future<bool> checkAvailability() async {
    try {
      // Simple availability check - query system health table
      final response = await _supabase
          .from('system_health')
          .select()
          .eq('id', 'health')
          .maybeSingle();

      return response != null && response['status'] == 'ok';
    } catch (e) {
      _logger.e('Availability check failed: $e');
      return false;
    }
  }
}
