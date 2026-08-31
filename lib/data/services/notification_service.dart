import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/notification_priority.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cooldown tracking (in-memory + persistent)
  final Map<String, DateTime> _cooldowns = {};
  static const Duration _defaultCooldown = Duration(minutes: 45);
  static const Duration _momentumCooldown = Duration(minutes: 30);

  // Badge counters
  final Map<String, int> _badgeCounts = {
    'chat': 0,
    'lobby': 0,
    'invites': 0,
  };

  bool _initialized = false;

  /// Initialize notification service with platform-specific configs
  Future<void> initialize() async {
    if (_initialized) return;

    // Android initialization
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization with permissions
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request FCM permissions
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notification permissions granted');
    }

    // Configure FCM handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Load cooldowns from persistent storage
    await _loadCooldowns();

    _initialized = true;
  }

  /// Handle foreground FCM messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📬 Foreground message: ${message.notification?.title}');

    // Convert FCM to local notification with custom handling
    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'SquadSync',
        body: message.notification!.body ?? '',
        payload: message.data,
        priority: _determinePriority(message.data),
      );
    }
  }

  /// Handle notification tap when app is in background
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    debugPrint('👆 Notification tapped: ${message.data}');
    // TODO: Navigate to relevant screen based on payload
  }

  /// Determine notification priority from payload
  NotificationPriority _determinePriority(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'direct_invite':
      case 'momentum':
        return NotificationPriority.high;
      case 'spot_available':
      case 'timer_expiring':
        return NotificationPriority.medium;
      default:
        return NotificationPriority.low;
    }
  }

  /// Show local notification with priority handling
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
    required NotificationPriority priority,
    String? imageUrl,
  }) async {
    // Check cooldown
    final cooldownKey =
        '${payload['user_id']}_${payload['lobby_id']}_${payload['type']}';
    if (_isOnCooldown(cooldownKey)) {
      debugPrint('🚫 Notification on cooldown: $cooldownKey');
      return;
    }

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (priority == NotificationPriority.low) {
      // Badge only - no sound/vibration
      await _updateBadge(payload['type'] as String? ?? 'lobby');
      return;
    }

    // High/Medium priority - show push notification
    final androidDetails = AndroidNotificationDetails(
      _getChannelId(priority),
      _getChannelName(priority),
      channelDescription: _getChannelDescription(priority),
      importance: priority == NotificationPriority.high
          ? Importance.high
          : Importance.defaultImportance,
      priority: priority == NotificationPriority.high
          ? Priority.high
          : Priority.defaultPriority,
      ticker: 'SquadSync',
      styleInformation: imageUrl != null
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(imageUrl),
              contentTitle: title,
              summaryText: body,
            )
          : BigTextStyleInformation(body),
      enableVibration: true,
      playSound: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      attachments:
          imageUrl != null ? [DarwinNotificationAttachment(imageUrl)] : null,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: _encodePayload(payload),
    );

    // Set cooldown
    _setCooldown(
      cooldownKey,
      payload['type'] == 'momentum' ? _momentumCooldown : _defaultCooldown,
    );
  }

  /// Send momentum notification when lobby fills
  Future<void> sendMomentumNotification({
    required String lobbyId,
    required String gameName,
    required int currentPlayers,
    required int maxPlayers,
    required String joinerName,
    required List<String> participantNames,
    String? gameImageUrl,
  }) async {
    // Query match history for affinity scoring
    final affinity = await _getMatchAffinity(lobbyId, gameName);

    // Only send to users with 3+ shared sessions
    final highAffinityUsers = affinity.where((a) => a.sharedSessionCount >= 3);

    for (final user in highAffinityUsers) {
      final spotPreview = '$currentPlayers/$maxPlayers spots';
      final tags = participantNames.take(3).join(', ');

      await _showLocalNotification(
        title: '🔥 $joinerName joined $gameName',
        body: '$spotPreview filled — $tags ready to play!',
        payload: {
          'type': 'momentum',
          'lobby_id': lobbyId,
          'user_id': user.userId,
          'game_name': gameName,
          'current_players': currentPlayers,
          'max_players': maxPlayers,
        },
        priority: NotificationPriority.high,
        imageUrl: gameImageUrl,
      );
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
    await _showLocalNotification(
      title: '🎮 $inviterName invited you',
      body: 'Join the $gameName lobby now!',
      payload: {
        'type': 'direct_invite',
        'lobby_id': lobbyId,
        'user_id': recipientId,
        'inviter_name': inviterName,
        'game_name': gameName,
      },
      priority: NotificationPriority.high,
      imageUrl: gameImageUrl,
    );
  }

  /// Send spot available notification
  Future<void> sendSpotAvailable({
    required String lobbyId,
    required String gameName,
    required int spotsOpen,
    required List<String> friendsInLobby,
  }) async {
    final friendsList = friendsInLobby.take(3).join(', ');
    await _showLocalNotification(
      title: '🎯 Spot available in $gameName',
      body: '$spotsOpen open — $friendsList waiting',
      payload: {
        'type': 'spot_available',
        'lobby_id': lobbyId,
        'game_name': gameName,
        'spots_open': spotsOpen,
      },
      priority: NotificationPriority.medium,
    );
  }

  /// Query match history for affinity scoring
  Future<List<MatchAffinity>> _getMatchAffinity(
    String lobbyId,
    String gameName,
  ) async {
    try {
      final response = await _supabase
          .from('match_history')
          .select('user_id, game_id, created_at')
          .eq('lobby_id', lobbyId)
          .order('created_at', ascending: false)
          .limit(100);

      final userGameCounts = <String, int>{};
      final userLastPlayed = <String, DateTime>{};

      for (final row in response as List) {
        final userId = row['user_id'] as String;
        final gameId = row['game_id'] as String;
        final createdAt = DateTime.parse(row['created_at'] as String);

        if (gameId == gameName) {
          userGameCounts[userId] = (userGameCounts[userId] ?? 0) + 1;
          userLastPlayed[userId] = createdAt;
        }
      }

      return userGameCounts.entries
          .map((e) => MatchAffinity(
                userId: e.key,
                gameId: gameName,
                sharedSessionCount: e.value,
                lastPlayedTogether: userLastPlayed[e.key]!,
                affinityScore: _calculateAffinityScore(
                  e.value,
                  userLastPlayed[e.key]!,
                ),
              ))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching match affinity: $e');
      return [];
    }
  }

  /// Calculate affinity score (0-100) based on shared sessions and recency
  double _calculateAffinityScore(int sessionCount, DateTime lastPlayed) {
    final daysSinceLastPlayed = DateTime.now().difference(lastPlayed).inDays;
    final sessionScore = (sessionCount * 10).clamp(0, 60).toDouble();
    final recencyScore =
        (40 - (daysSinceLastPlayed * 2)).clamp(0, 40).toDouble();
    return sessionScore + recencyScore;
  }

  /// Check if notification is on cooldown
  bool _isOnCooldown(String key) {
    final lastSent = _cooldowns[key];
    if (lastSent == null) return false;
    return DateTime.now().difference(lastSent) < _defaultCooldown;
  }

  /// Set cooldown for notification key
  void _setCooldown(String key, Duration duration) {
    _cooldowns[key] = DateTime.now();
    _saveCooldowns(); // Persist to SharedPreferences
  }

  /// Load cooldowns from persistent storage
  Future<void> _loadCooldowns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('notification_cooldowns');
      if (json != null) {
        // Parse stored cooldowns (JSON format)
        // TODO: Implement JSON deserialization
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load cooldowns: $e');
    }
  }

  /// Save cooldowns to persistent storage
  Future<void> _saveCooldowns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // TODO: Serialize cooldowns to JSON
      await prefs.setString('notification_cooldowns', '{}');
    } catch (e) {
      debugPrint('⚠️ Failed to save cooldowns: $e');
    }
  }

  /// Update in-app badge count
  Future<void> _updateBadge(String type) async {
    _badgeCounts[type] = (_badgeCounts[type] ?? 0) + 1;

    if (Platform.isIOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(badge: true);
      // Set iOS app badge
      // Note: Requires additional plugin or native code
    }
  }

  /// Get channel ID based on priority
  String _getChannelId(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.high:
        return 'squadsync_high_priority';
      case NotificationPriority.medium:
        return 'squadsync_medium_priority';
      case NotificationPriority.low:
        return 'squadsync_low_priority';
    }
  }

  /// Get channel name based on priority
  String _getChannelName(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.high:
        return 'High Priority Alerts';
      case NotificationPriority.medium:
        return 'Medium Priority Alerts';
      case NotificationPriority.low:
        return 'Low Priority Updates';
    }
  }

  /// Get channel description
  String _getChannelDescription(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.high:
        return 'Direct invites and momentum notifications';
      case NotificationPriority.medium:
        return 'Spot availability and timer alerts';
      case NotificationPriority.low:
        return 'Chat and lobby update badges';
    }
  }

  /// Encode payload to JSON string
  String _encodePayload(Map<String, dynamic> payload) {
    // Simple encoding - can be enhanced with proper JSON
    return payload.toString();
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Notification tapped: ${response.payload}');
    // TODO: Parse payload and navigate to relevant screen
  }

  /// Get badge state
  BadgeState getBadgeState() {
    return BadgeState(
      chatUnreadCount: _badgeCounts['chat'] ?? 0,
      lobbyUpdatesCount: _badgeCounts['lobby'] ?? 0,
      invitesCount: _badgeCounts['invites'] ?? 0,
    );
  }

  /// Clear badge for specific type
  void clearBadge(String type) {
    _badgeCounts[type] = 0;
  }

  /// Clear all badges
  void clearAllBadges() {
    _badgeCounts.clear();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message: ${message.notification?.title}');
}
