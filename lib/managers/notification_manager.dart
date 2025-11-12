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

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onDidReceiveBackgroundNotificationResponse,
    );

    // Create notification channels for different types
    await _createNotificationChannels();
  }

  static Future<void> _onDidReceiveNotificationResponse(
      NotificationResponse response) async {
    final String? payload = response.payload;
    if (payload != null) {
      await _handleNotificationAction(payload, response.actionId);
    }
  }

  static Future<void> _onDidReceiveBackgroundNotificationResponse(
      NotificationResponse response) async {
    final String? payload = response.payload;
    if (payload != null) {
      await _handleNotificationAction(payload, response.actionId);
    }
  }

  static Future<void> _handleNotificationAction(
      String payload, String? actionId) async {
    final parts = payload.split(':');
    if (parts.isEmpty) return;

    final notificationType = parts[0];

    switch (notificationType) {
      case 'timer_warning':
        if (actionId == 'extend_timer' && parts.length >= 3) {
          final player = parts[1];
          // TODO: Implement timer extension logic
          debugPrint('Extending timer for $player by 5 minutes');
        }
        break;
      case 'ban_warning':
        if (actionId == 'view_profile' && parts.length >= 2) {
          final player = parts[1];
          // TODO: Navigate to player profile
          debugPrint('Viewing profile for $player');
        }
        break;
      case 'achievement':
        if (actionId == 'view_achievements' && parts.length >= 2) {
          final player = parts[1];
          // TODO: Navigate to achievements screen
          debugPrint('Viewing achievements for $player');
        }
        break;
      case 'squad_spot':
        if (actionId == 'join_squad' && parts.length >= 2) {
          final game = parts[1];
          // TODO: Navigate to join squad for game
          debugPrint('Joining squad for $game');
        } else if (actionId == 'view_squad' && parts.length >= 2) {
          final game = parts[1];
          // TODO: Navigate to view squad for game
          debugPrint('Viewing squad for $game');
        }
        break;
      case 'chat_mention':
        if (actionId == 'reply_chat' && parts.length >= 2) {
          final sender = parts[1];
          // TODO: Navigate to chat and focus reply input
          debugPrint('Replying to chat mention from $sender');
        } else if (actionId == 'view_chat') {
          // TODO: Navigate to chat screen
          debugPrint('Viewing chat');
        }
        break;
    }
  }

  static Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel squadChannel = AndroidNotificationChannel(
      'squad_channel',
      'Squad Notifications',
      description: 'Notifications about squad activities and spots',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Notifications',
      description: 'Notifications for new messages and mentions',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    const AndroidNotificationChannel achievementChannel =
        AndroidNotificationChannel(
      'achievement_channel',
      'Achievement Notifications',
      description: 'Notifications for unlocked achievements',
      importance: Importance.low,
      playSound: false,
    );

    const AndroidNotificationChannel timerChannel = AndroidNotificationChannel(
      'timer_channel',
      'Timer Notifications',
      description: 'Notifications for timer warnings and alerts',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
      'general_channel',
      'General Notifications',
      description: 'General app notifications',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(squadChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(chatChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(achievementChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(timerChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
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

  Future<void> showSmartNotification({
    required String title,
    required String body,
    required String channelId,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: _getChannelImportance(channelId),
      priority: Priority.high,
      showWhen: true,
      actions: actions,
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
    notifyListeners();
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'squad_channel':
        return 'Squad Notifications';
      case 'chat_channel':
        return 'Chat Notifications';
      case 'achievement_channel':
        return 'Achievement Notifications';
      case 'timer_channel':
        return 'Timer Notifications';
      case 'general_channel':
        return 'General Notifications';
      default:
        return 'SquadSync Notifications';
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'squad_channel':
        return 'Notifications about squad activities and spots';
      case 'chat_channel':
        return 'Notifications for new messages and mentions';
      case 'achievement_channel':
        return 'Notifications for unlocked achievements';
      case 'timer_channel':
        return 'Notifications for timer warnings and alerts';
      case 'general_channel':
        return 'General app notifications';
      default:
        return 'Notifications for SquadSync app';
    }
  }

  Importance _getChannelImportance(String channelId) {
    switch (channelId) {
      case 'squad_channel':
      case 'timer_channel':
        return Importance.high;
      case 'chat_channel':
      case 'general_channel':
        return Importance.defaultImportance;
      case 'achievement_channel':
        return Importance.low;
      default:
        return Importance.defaultImportance;
    }
  }

  Future<void> showTimerWarning(String player, int minutesLeft) async {
    if (!isNotificationEnabled('timer_warning')) return;

    final actions = [
      AndroidNotificationAction(
        'extend_timer',
        'Extend 5 min',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        'dismiss_timer',
        'Dismiss',
        showsUserInterface: false,
      ),
    ];

    await showSmartNotification(
      title: 'Timer Warning',
      body: '$player has $minutesLeft minutes left!',
      channelId: 'timer_channel',
      payload: 'timer_warning:$player:$minutesLeft',
      actions: actions,
    );
  }

  Future<void> showBanWarning(String player, int banCount) async {
    if (!isNotificationEnabled('ban_warning')) return;

    final actions = [
      AndroidNotificationAction(
        'view_profile',
        'View Profile',
        showsUserInterface: true,
      ),
    ];

    await showSmartNotification(
      title: 'Ban Warning',
      body: '$player has been banned $banCount times',
      channelId: 'general_channel',
      payload: 'ban_warning:$player:$banCount',
      actions: actions,
    );
  }

  Future<void> showAchievementNotification(
      String player, String achievement) async {
    if (!isNotificationEnabled('achievement')) return;

    final actions = [
      AndroidNotificationAction(
        'view_achievements',
        'View All',
        showsUserInterface: true,
      ),
    ];

    await showSmartNotification(
      title: 'Achievement Unlocked!',
      body: '$player earned: $achievement',
      channelId: 'achievement_channel',
      payload: 'achievement:$player:$achievement',
      actions: actions,
    );
  }

  Future<void> showSquadSpotNotification(
      String game, String spotClaimedBy) async {
    if (!isNotificationEnabled('spot_available')) return;

    final actions = [
      AndroidNotificationAction(
        'join_squad',
        'Join Squad',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        'view_squad',
        'View Squad',
        showsUserInterface: true,
      ),
    ];

    await showSmartNotification(
      title: 'Squad Spot Available',
      body: 'A spot opened up in $game squad',
      channelId: 'squad_channel',
      payload: 'squad_spot:$game:$spotClaimedBy',
      actions: actions,
    );
  }

  Future<void> showChatMentionNotification(
      String sender, String message) async {
    if (!isNotificationEnabled('chat_mention')) return;

    final actions = [
      AndroidNotificationAction(
        'reply_chat',
        'Reply',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        'view_chat',
        'View Chat',
        showsUserInterface: true,
      ),
    ];

    await showSmartNotification(
      title: 'Chat Mention',
      body:
          '$sender mentioned you: ${message.length > 50 ? '${message.substring(0, 50)}...' : message}',
      channelId: 'chat_channel',
      payload: 'chat_mention:$sender:$message',
      actions: actions,
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

  /// Stream of unread notification count
  Stream<int> getUnreadNotificationCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
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
