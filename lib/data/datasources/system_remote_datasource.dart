import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:timezone/timezone.dart' as tz;

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
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final http.Client _httpClient;
  final String? _analyticsEndpoint;

  SystemRemoteDataSourceImpl(
    this._firestore,
    this._auth,
    this._localNotifications,
    this._httpClient,
    this._analyticsEndpoint,
  );

  @override
  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailabilitySlots(String userId) async {
    final snapshot = await _firestore
        .collection('availability')
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Future<Map<String, Map<String, bool>>> getDailyBanVotes() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final snapshot = await _firestore
        .collection('ban_votes')
        .where('date', isEqualTo: today)
        .get();

    final dailyBanVotes = <String, Map<String, bool>>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final voterId = data['voterId'] as String;
      final targetId = data['targetId'] as String;
      final vote = data['vote'] as bool;

      dailyBanVotes.putIfAbsent(voterId, () => {})[targetId] = vote;
    }

    return dailyBanVotes;
  }

  @override
  Future<List<Map<String, dynamic>>> getBans(String userId) async {
    final snapshot = await _firestore
        .collection('bans')
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Future<void> addNotification(
      String userId, Map<String, dynamic> notification) async {
    await _firestore.collection('notifications').add({
      ...notification,
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  @override
  Future<void> markNotificationsAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  @override
  Future<void> addAvailabilitySlot(
      String userId, Map<String, dynamic> slot) async {
    await _firestore.collection('availability').add({
      ...slot,
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeAvailabilitySlot(String slotId) async {
    await _firestore.collection('availability').doc(slotId).delete();
  }

  @override
  Future<void> updateAvailabilitySlot(
      String slotId, Map<String, dynamic> updates) async {
    await _firestore.collection('availability').doc(slotId).update(updates);
  }

  @override
  Future<void> submitBanVote(
      String voterId, String targetUserId, bool vote) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _firestore.collection('ban_votes').add({
      'voterId': voterId,
      'targetId': targetUserId,
      'vote': vote,
      'date': today,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> sendAnalyticsEvent(
      String event, Map<String, dynamic> data) async {
    if (_analyticsEndpoint == null) return;

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
    // For now, return empty map
    return {};
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
    final batch = _firestore.batch();

    final snapshot = await _firestore
        .collection('notifications')
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoff))
        .get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  @override
  Future<void> resetDailyVotes() async {
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')[0];
    final batch = _firestore.batch();

    final snapshot = await _firestore
        .collection('ban_votes')
        .where('date', isLessThan: yesterday)
        .get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  @override
  Future<void> purgeOldData({Duration? olderThan}) async {
    final cutoff =
        DateTime.now().subtract(olderThan ?? const Duration(days: 30));

    // Purge old notifications
    await clearOldNotifications(olderThan: olderThan);

    // Purge old availability slots
    final availabilityBatch = _firestore.batch();
    final availabilitySnapshot = await _firestore
        .collection('availability')
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoff))
        .get();

    for (var doc in availabilitySnapshot.docs) {
      availabilityBatch.delete(doc.reference);
    }

    await availabilityBatch.commit();

    // Purge old ban votes
    await resetDailyVotes();
  }

  @override
  Future<void> banUser(String userId, String reason) async {
    await _firestore.collection('bans').doc(userId).set({
      'userId': userId,
      'reason': reason,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': _auth.currentUser?.uid,
    });
  }

  @override
  Future<void> unbanUser(String userId) async {
    await _firestore.collection('bans').doc(userId).delete();
  }

  @override
  Future<bool> checkAvailability() async {
    try {
      // Simple availability check - could be more sophisticated
      await _firestore.collection('system').doc('health').get();
      return true;
    } catch (e) {
      return false;
    }
  }
}
