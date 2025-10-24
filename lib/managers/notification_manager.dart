import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages app notifications and alerts
class NotificationManager with ChangeNotifier {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  bool notificationsEnabled = true;
  Map<String, bool> notificationTypes = {
    'game_start': true,
    'spot_available': true,
    'timer_warning': true,
    'ban_warning': true,
    'achievement': true,
  };

  void setNotificationsEnabled(bool enabled) {
    notificationsEnabled = enabled;
    notifyListeners();
  }

  void setNotificationType(String type, bool enabled) {
    notificationTypes[type] = enabled;
    notifyListeners();
  }

  bool isNotificationEnabled(String type) {
    return notificationsEnabled && (notificationTypes[type] ?? true);
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
    notifyListeners();
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'scheduled_channel_id',
      'Scheduled Notifications',
      channelDescription: 'Channel for scheduled notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    notifyListeners();
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    notifyListeners();
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    notifyListeners();
  }

  Future<void> showTimerWarning(String player, int minutesLeft) async {
    if (!isNotificationEnabled('timer_warning')) return;

    await showNotification(
      title: 'Timer Warning',
      body: '$player has $minutesLeft minutes left!',
    );
  }

  Future<void> showBanWarning(String player, int banCount) async {
    if (!isNotificationEnabled('ban_warning')) return;

    await showNotification(
      title: 'Ban Warning',
      body: '$player has been banned $banCount times',
    );
  }

  Future<void> showAchievementNotification(
      String player, String achievement) async {
    if (!isNotificationEnabled('achievement')) return;

    await showNotification(
      title: 'Achievement Unlocked!',
      body: '$player earned: $achievement',
    );
  }

  // Stream methods for smart feed
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getFilteredNotificationsStream({Set<String>? mutedGames}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(100); // Get more to allow for filtering

    return query.snapshots().map((snapshot) {
      final docs = snapshot.docs;
      if (mutedGames == null || mutedGames.isEmpty) {
        return docs;
      }

      // Filter out notifications for muted games
      return docs.where((doc) {
        final data = doc.data();
        final game = data['game'] as String?;
        return game == null || !mutedGames.contains(game);
      }).toList();
    });
  }

  Future<void> createNotification({
    required String type,
    required String title,
    required String body,
    String? game,
    Map<String, dynamic>? data,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'type': type,
        'title': title,
        'body': body,
        'game': game,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': data ?? {},
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> archiveNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error archiving notification: $e');
    }
  }
}
