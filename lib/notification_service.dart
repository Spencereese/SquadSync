import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/io_platform.dart';
import 'core/notification_cooldowns.dart';
import 'core/notification_routes.dart';
import 'domain/entities/notification_priority.dart';
import 'services/auth_service_supabase.dart';
import 'services/supabase_service.dart';

/// Live notification service (imported from main + peacock).
/// Cooldown expiry + iOS badge push live here — not in the deleted
/// `lib/data/services/notification_service.dart` duplicate.
class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final NotificationCooldownStore _cooldowns = NotificationCooldownStore();
  final Map<String, int> _badgeCounts = {
    'chat': 0,
    'lobby': 0,
    'invites': 0,
  };
  bool _initialized = false;

  static Future<void> initialize() => _instance._initialize();

  Future<void> _initialize() async {
    if (_initialized) return;

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            NotificationRoutes.open(decoded);
          } else if (decoded is Map) {
            NotificationRoutes.open(decoded.cast<String, dynamic>());
          }
        } catch (e) {
          developer.log('Notification payload was not JSON: $e');
        }
      },
    );

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );
    developer.log('User granted permission: ${settings.authorizationStatus}');

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log(
          'Foreground message: ${message.notification?.title} - ${message.notification?.body}');
      if (message.notification != null && kIsIos) {
        _instance._showLocalNotification(
          title: message.notification?.title ?? 'Cod Squad',
          body: message.notification?.body ?? '',
          payload: message.data,
        );
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      final token = await _messaging.getToken();
      developer.log('FCM Token: $token');
      final user = AuthServiceSupabase().currentUser;
      if (user != null && token != null) {
        await SupabaseService.client.from('users').update({
          'fcm_token': token,
        }).eq('uid', user.id);
      }
    } catch (e) {
      developer.log('FCM token unavailable (expected on simulator): $e');
    }
    _messaging.onTokenRefresh.listen((newToken) async {
      developer.log('New FCM Token: $newToken');
      try {
        final currentUser = AuthServiceSupabase().currentUser;
        if (currentUser != null) {
          await SupabaseService.client.from('users').update({
            'fcm_token': newToken,
          }).eq('uid', currentUser.id);
        }
      } catch (e) {
        developer.log('FCM token refresh store skipped: $e');
      }
    });

    await _instance._loadCooldowns();
    _initialized = true;
  }

  static void _handleMessage(RemoteMessage message) {
    developer.log('Handling message: ${message.data}');
    NotificationRoutes.open(message.data);
  }

  static Future<void> sendNotification(String title, String body) async {
    developer.log('Sending broadcast notification: $title - $body');
  }

  /// Send via Supabase Edge Function (FCM v1). No legacy server-key HTTP.
  static Future<void> sendNotificationToUsers({
    required String title,
    required String body,
    required List<String> recipientUids,
    Map<String, dynamic>? data,
  }) async {
    if (recipientUids.isEmpty) {
      developer.log('No recipients specified for notification');
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('users')
          .select('uid, fcm_token')
          .inFilter('uid', recipientUids);

      if (response.isEmpty) {
        developer.log('No FCM tokens found for recipients');
        return;
      }

      final tokens = <String>[];
      for (final user in response) {
        final token = user['fcm_token'] as String?;
        if (token != null && token.isNotEmpty) {
          tokens.add(token);
        }
      }

      if (tokens.isEmpty) {
        developer.log('No valid FCM tokens available');
        return;
      }

      developer.log(
          'Sending notifications to ${tokens.length} users via Supabase Edge Function');

      final edgeFunctionResponse =
          await SupabaseService.client.functions.invoke(
        'send-push-notification',
        body: {
          'tokens': tokens,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );

      if (edgeFunctionResponse.status == 200) {
        developer.log('Notifications sent successfully via Edge Function');
      } else {
        developer.log(
            'Edge Function response: ${edgeFunctionResponse.status} - ${edgeFunctionResponse.data}');
      }
    } catch (e) {
      developer.log('Error sending notifications: $e');
    }
  }

  /// Look up the user and send through [sendNotificationToUsers].
  /// The old `https://fcm.googleapis.com/fcm/send` + YOUR_FCM_SERVER_KEY path is gone.
  static Future<void> sendNotificationToUser({
    required String recipientDisplayName,
    required String title,
    required String body,
  }) async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .select('uid, fcm_token')
          .eq('display_name', recipientDisplayName)
          .maybeSingle();

      if (response == null) {
        developer.log('No user found for $recipientDisplayName');
        return;
      }
      final uid = response['uid'] as String?;
      if (uid == null || uid.isEmpty) {
        developer.log('No uid for $recipientDisplayName');
        return;
      }
      await sendNotificationToUsers(
        title: title,
        body: body,
        recipientUids: [uid],
        data: const {'screen': 'squad'},
      );
    } catch (e) {
      developer.log('Error sending notification to $recipientDisplayName: $e');
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
    NotificationPriority priority = NotificationPriority.medium,
  }) async {
    final cooldownKey =
        '${payload['user_id']}_${payload['lobby_id']}_${payload['type']}';
    if (_isOnCooldown(cooldownKey)) {
      developer.log('Notification on cooldown: $cooldownKey');
      return;
    }

    if (priority == NotificationPriority.low) {
      await _updateBadge(payload['type'] as String? ?? 'lobby');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'channel_id',
      'Cod Squad Notifications',
      channelDescription: 'Notifications for Cod Squad',
      importance: Importance.max,
      priority: Priority.high,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: _totalBadgeCount,
    );
    final notificationDetails = NotificationDetails(
      iOS: iosDetails,
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(payload),
    );

    _setCooldown(
      cooldownKey,
      payload['type'] == 'momentum'
          ? NotificationCooldownStore.momentumDuration
          : NotificationCooldownStore.defaultDuration,
    );
  }

  Future<void> sendMomentumNotification({
    required String lobbyId,
    required String gameName,
    required int currentPlayers,
    required int maxPlayers,
    required String joinerName,
    required List<String> participantNames,
    String? gameImageUrl,
  }) async {
    final spotPreview = '$currentPlayers/$maxPlayers spots';
    final tags = participantNames.take(3).join(', ');
    await _showLocalNotification(
      title: '$joinerName joined $gameName',
      body: '$spotPreview filled — $tags ready to play!',
      payload: {
        'type': 'momentum',
        'lobby_id': lobbyId,
        'game_name': gameName,
        'current_players': currentPlayers,
        'max_players': maxPlayers,
      },
      priority: NotificationPriority.high,
    );
  }

  Future<void> sendDirectInvite({
    required String recipientId,
    required String inviterName,
    required String lobbyId,
    required String gameName,
    String? gameImageUrl,
  }) async {
    await _showLocalNotification(
      title: '$inviterName invited you',
      body: 'Join the $gameName lobby now!',
      payload: {
        'type': 'direct_invite',
        'lobby_id': lobbyId,
        'user_id': recipientId,
        'inviter_name': inviterName,
        'game_name': gameName,
      },
      priority: NotificationPriority.high,
    );
    await sendNotificationToUsers(
      title: '$inviterName invited you',
      body: 'Join the $gameName lobby now!',
      recipientUids: [recipientId],
      data: {
        'type': 'direct_invite',
        'lobby_id': lobbyId,
      },
    );
  }

  Future<void> sendSpotAvailable({
    required String lobbyId,
    required String gameName,
    required int spotsOpen,
    required List<String> friendsInLobby,
  }) async {
    final friendsList = friendsInLobby.take(3).join(', ');
    await _showLocalNotification(
      title: 'Spot available in $gameName',
      body: '$spotsOpen open — $friendsList waiting',
      payload: {
        'type': 'spot_available',
        'lobby_id': lobbyId,
        'game_name': gameName,
        'spots_open': spotsOpen,
      },
    );
  }

  bool _isOnCooldown(String key) => _cooldowns.isActive(key);

  void _setCooldown(String key, Duration duration) {
    _cooldowns.setExpiry(key, duration);
    _saveCooldowns();
  }

  Future<void> _loadCooldowns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawV2 = prefs.getString(NotificationCooldownStore.prefsKeyV2);
      if (rawV2 != null && rawV2.isNotEmpty) {
        final decoded = jsonDecode(rawV2);
        _cooldowns.loadPersisted(decoded);
        return;
      }
      final rawV1 = prefs.getString(NotificationCooldownStore.prefsKeyV1);
      if (rawV1 == null || rawV1.isEmpty) return;
      final decoded = jsonDecode(rawV1);
      final migrated = _cooldowns.loadPersisted(decoded);
      if (migrated) {
        await _saveCooldowns();
        await prefs.remove(NotificationCooldownStore.prefsKeyV1);
      }
    } catch (e) {
      developer.log('Failed to load cooldowns: $e');
    }
  }

  Future<void> _saveCooldowns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        NotificationCooldownStore.prefsKeyV2,
        jsonEncode(_cooldowns.toPersistedJson()),
      );
    } catch (e) {
      developer.log('Failed to save cooldowns: $e');
    }
  }

  int get _totalBadgeCount =>
      _badgeCounts.values.fold<int>(0, (sum, count) => sum + count);

  Future<void> _updateBadge(String type) async {
    incrementBadge(type);
  }

  void incrementBadge(String type) {
    _badgeCounts[type] = (_badgeCounts[type] ?? 0) + 1;
    _pushIosBadgeCount();
  }

  BadgeState getBadgeState() {
    return BadgeState(
      chatUnreadCount: _badgeCounts['chat'] ?? 0,
      lobbyUpdatesCount: _badgeCounts['lobby'] ?? 0,
      invitesCount: _badgeCounts['invites'] ?? 0,
    );
  }

  void clearBadge(String type) {
    _badgeCounts[type] = 0;
    _pushIosBadgeCount();
  }

  void clearAllBadges() {
    _badgeCounts.updateAll((key, value) => 0);
    _pushIosBadgeCount();
  }

  void _pushIosBadgeCount() {
    if (!kIsIos) return;
    _localNotifications.show(
      0,
      null,
      null,
      NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentSound: false,
          presentBadge: true,
          badgeNumber: _totalBadgeCount,
        ),
      ),
    );
  }
}

/// Must be top-level for FCM background isolates.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log(
      'Background message: ${message.notification?.title} - ${message.notification?.body}');
}
