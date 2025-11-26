import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'managers/stubs.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      // Use NotificationManager to handle token storage
      final notificationManager = NotificationManager();
      await notificationManager.updateFCMToken(token);
    }
    _messaging.onTokenRefresh.listen((newToken) async {
      developer.log('New FCM Token: $newToken');
      if (user != null) {
        // Use NotificationManager to update token
        final notificationManager = NotificationManager();
        await notificationManager.updateFCMToken(newToken);
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

  static Future<void> sendNotificationToUser({
    required String recipientDisplayName,
    required String title,
    required String body,
  }) async {
    try {
      // Find the user's FCM token by displayName
      final userDocs = await _firestore
          .collection('users')
          .where('displayName', isEqualTo: recipientDisplayName)
          .limit(1)
          .get();
      if (userDocs.docs.isEmpty) {
        developer.log('No FCM token found for $recipientDisplayName');
        return;
      }
      final fcmToken = userDocs.docs.first.data()['fcmToken'] as String?;

      if (fcmToken == null) {
        developer.log('FCM token not available for $recipientDisplayName');
        return;
      }

      // FCM server key (replace with your Firebase project's server key)
      const serverKey = 'YOUR_FCM_SERVER_KEY_HERE'; // Add from Firebase Console
      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');

      final response = await http.post(
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

      if (response.statusCode == 200) {
        developer
            .log('Notification sent to $recipientDisplayName: $title - $body');
      } else {
        developer.log('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      developer.log('Error sending notification to $recipientDisplayName: $e');
    }
  }
}
