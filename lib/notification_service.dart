import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize local notifications
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
    await _localNotifications.initialize(initSettings);

    // Request permissions for iOS
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );
    developer.log('User granted permission: ${settings.authorizationStatus}');

    // Set foreground notification presentation options (iOS)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log(
          'Foreground message: ${message.notification?.title} - ${message.notification?.body}');
      if (message.notification != null && Platform.isIOS) {
        _showLocalNotification(message);
      }
    });

    // Handle notifications when app is opened from terminated state
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Handle notifications when app is in background and opened
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Background messages
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // Store FCM token for the current user
    String? token = await _messaging.getToken();
    developer.log('FCM Token: $token');
    final user = AuthServiceSupabase().currentUser;
    if (user != null && token != null) {
      await SupabaseService.client.from('users').update({
        'fcm_token': token,
      }).eq('id', user.id);
    }
    _messaging.onTokenRefresh.listen((newToken) async {
      developer.log('New FCM Token: $newToken');
      final currentUser = AuthServiceSupabase().currentUser;
      if (currentUser != null) {
        await SupabaseService.client.from('users').update({
          'fcm_token': newToken,
        }).eq('id', currentUser.id);
      }
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const androidDetails = AndroidNotificationDetails(
      'channel_id',
      'SquadSync Notifications',
      channelDescription: 'Notifications for SquadSync app',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(
      iOS: iosDetails,
      android: androidDetails,
    );

    await _localNotifications.show(
      message.messageId.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
    );
  }

  static Future<void> _backgroundHandler(RemoteMessage message) async {
    developer.log(
        'Background message: ${message.notification?.title} - ${message.notification?.body}');
  }

  static void _handleMessage(RemoteMessage message) {
    developer.log('Handling message: ${message.data}');

    final data = message.data;
    final type = data['type'];

    switch (type) {
      case 'lobby_join':
        final lobbyId = data['lobbyId'];
        final gameName = data['gameName'] ?? '';
        final hostName = data['hostName'] ?? '';
        developer.log(
            'Should navigate to lobby: $lobbyId for $gameName hosted by $hostName');
        // TODO: Navigate to lobby screen
        break;
      case 'chat':
        if (data['screen'] == 'chat') {
          developer.log('Should navigate to ChatScreen');
        }
        break;
      default:
        developer.log('Unknown message type: $type');
    }
  }

  static Future<void> sendNotification(String title, String body) async {
    // Broadcast notification (for testing or squad-wide alerts)
    developer.log('Sending broadcast notification: $title - $body');
  }

  /// Send notification to multiple users by UIDs using FCM v1 API
  ///
  /// [title] - Notification title
  /// [body] - Notification body
  /// [recipientUids] - List of user UIDs to send notification to
  /// [data] - Optional data payload for navigation/actions
  ///
  /// IMPORTANT: This uses Supabase Edge Function to send FCM notifications
  /// The Edge Function handles OAuth2 authentication with service account credentials
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
      // Fetch FCM tokens for all recipients
      final response = await SupabaseService.client
          .from('users')
          .select('id, fcm_token')
          .inFilter('id', recipientUids);

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

      // Call Supabase Edge Function to send notifications
      // The Edge Function handles FCM v1 API authentication
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
        developer.log('✅ Notifications sent successfully via Edge Function');
      } else {
        developer.log(
            '⚠️ Edge Function response: ${edgeFunctionResponse.status} - ${edgeFunctionResponse.data}');
      }
    } catch (e) {
      developer.log('❌ Error sending notifications: $e');
      // Gracefully fail - don't block the main operation
    }
  }

  static Future<void> sendNotificationToUser({
    required String recipientDisplayName,
    required String title,
    required String body,
  }) async {
    try {
      // Find the user's FCM token by displayName
      final response = await SupabaseService.client
          .from('users')
          .select('fcm_token')
          .eq('display_name', recipientDisplayName)
          .maybeSingle();

      if (response == null) {
        developer.log('No FCM token found for $recipientDisplayName');
        return;
      }
      final fcmToken = response['fcm_token'] as String?;

      if (fcmToken == null) {
        developer.log('FCM token not available for $recipientDisplayName');
        return;
      }

      // FCM server key (replace with your Firebase project's server key)
      const serverKey = 'YOUR_FCM_SERVER_KEY_HERE'; // Add from Firebase Console
      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');

      final response2 = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'screen': 'squad', // Optional: for navigation on tap
          },
        }),
      );

      if (response2.statusCode == 200) {
        developer
            .log('Notification sent to $recipientDisplayName: $title - $body');
      } else {
        developer.log('Failed to send notification: ${response2.body}');
      }
    } catch (e) {
      developer.log('Error sending notification to $recipientDisplayName: $e');
    }
  }
}
