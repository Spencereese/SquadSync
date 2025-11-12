import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages app notifications and alerts
class NotificationManager with ChangeNotifier {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationManager() {
    _loadNotificationSettings();
  }

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

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
      case 'lobby_join':
        if (actionId == 'join_lobby' && parts.length >= 2) {
          final lobbyId = parts[1];
          final gameName = parts.length >= 3 ? parts[2] : '';
          final hostName = parts.length >= 4 ? parts[3] : '';
          // TODO: Navigate to lobby and join it
          debugPrint(
              'Joining lobby $lobbyId for $gameName hosted by $hostName');
        } else if (actionId == 'view_lobby' && parts.length >= 2) {
          final lobbyId = parts[1];
          final gameName = parts.length >= 3 ? parts[2] : '';
          final hostName = parts.length >= 4 ? parts[3] : '';
          // TODO: Navigate to view lobby details
          debugPrint(
              'Viewing lobby $lobbyId for $gameName hosted by $hostName');
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

    const AndroidNotificationChannel gamingLobbyChannel =
        AndroidNotificationChannel(
      'gaming_lobby_channel',
      'Gaming Lobby Notifications',
      description: 'Persistent notifications for joinable gaming lobbies',
      importance: Importance.max,
      playSound: false,
      showBadge: true,
      enableVibration: false,
      enableLights: true,
      ledColor: Color.fromARGB(255, 0, 255, 0),
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

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(gamingLobbyChannel);
  }

  bool notificationsEnabled = true;
  Map<String, bool> notificationTypes = {
    'game_start': true,
    'spot_available': true,
    'timer_warning': true,
    'ban_warning': true,
    'achievement': true,
    'lobby_available': true,
  };

  // FCM token management
  Future<void> updateFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get current tokens
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final currentTokens =
          List<String>.from(userDoc.data()?['fcmTokens'] ?? []);

      // Add new token if not already present
      if (!currentTokens.contains(token)) {
        currentTokens.add(token);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmTokens': currentTokens,
        });
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  Future<void> removeFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get current tokens
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final currentTokens =
          List<String>.from(userDoc.data()?['fcmTokens'] ?? []);

      // Remove token
      currentTokens.remove(token);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmTokens': currentTokens,
      });
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }

  // Notification settings management
  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'notificationSettings': settings,
      }, SetOptions(merge: true));

      // Update local state
      notificationTypes.addAll(settings);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating notification settings: $e');
    }
  }

  Future<Map<String, bool>> getNotificationSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return notificationTypes;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final settings =
          userDoc.data()?['notificationSettings'] as Map<String, dynamic>?;

      if (settings != null) {
        final typedSettings =
            settings.map((key, value) => MapEntry(key, value as bool));
        // Update local state
        notificationTypes.addAll(typedSettings);
        return typedSettings;
      }
    } catch (e) {
      debugPrint('Error getting notification settings: $e');
    }

    return notificationTypes;
  }

  Future<void> _loadNotificationSettings() async {
    final settings = await getNotificationSettings();
    notificationTypes = Map.from(settings);
    notifyListeners();
  }

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
    bool ongoing = false,
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
      ongoing: ongoing,
      autoCancel: !ongoing, // Auto-cancel non-ongoing notifications when tapped
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
      case 'gaming_lobby_channel':
        return 'Gaming Lobby Notifications';
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
      case 'gaming_lobby_channel':
        return 'Persistent notifications for joinable gaming lobbies';
      default:
        return 'Notifications for SquadSync app';
    }
  }

  Importance _getChannelImportance(String channelId) {
    switch (channelId) {
      case 'squad_channel':
      case 'timer_channel':
        return Importance.high;
      case 'gaming_lobby_channel':
        return Importance.max;
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

  // Gaming Lobby Notifications
  Future<void> showPersistentLobbyNotification({
    required String lobbyId,
    required String gameName,
    required String hostName,
    required int currentPlayers,
    required int maxPlayers,
    required List<String> playerNames,
  }) async {
    if (!isNotificationEnabled('lobby_available')) return;

    final actions = [
      AndroidNotificationAction(
        'join_lobby',
        'Join Lobby',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        'view_lobby',
        'View Details',
        showsUserInterface: true,
      ),
    ];

    final playerList = playerNames.isNotEmpty
        ? playerNames.take(3).join(', ') +
            (playerNames.length > 3 ? ' +${playerNames.length - 3} more' : '')
        : 'Waiting for players';

    await showSmartNotification(
      title: '$hostName\'s $gameName Lobby',
      body: '$currentPlayers/$maxPlayers players • $playerList',
      channelId: 'gaming_lobby_channel',
      payload: 'lobby_join:$lobbyId:$gameName:$hostName',
      actions: actions,
      ongoing: true, // This makes it persistent until dismissed
    );
  }

  Future<void> dismissPersistentLobbyNotification(String lobbyId) async {
    // Cancel the specific notification by its ID
    // Since we use timestamp-based IDs, we need to find and cancel by payload or use a specific ID
    // For now, we'll cancel all ongoing notifications when a lobby is closed
    await cancelAllNotifications();
  }

  // Method to check for friend lobbies and show persistent notifications
  // This should be called periodically or when the app detects friend activity
  Future<void> checkAndShowFriendLobbyNotifications() async {
    // TODO: Implement server-side push notifications for friend lobbies
    // For now, this is a placeholder for the logic that would:
    // 1. Get current user's friends
    // 2. Check which friends have active lobbies
    // 3. Show persistent notifications for joinable friend lobbies
    // 4. Server-side implementation needed for cross-device notifications
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
