import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize local notifications for iOS foreground
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
      provisional: true, // Allows temporary notifications without prompt
    );
    print('User granted permission: ${settings.authorizationStatus}');

    // Set foreground notification presentation options (iOS)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
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

    // Get and monitor FCM token
    String? token = await _messaging.getToken();
    print('FCM Token: $token');
    _messaging.onTokenRefresh.listen((newToken) {
      print('New FCM Token: $newToken');
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
    print(
        'Background message: ${message.notification?.title} - ${message.notification?.body}');
  }

  static void _handleMessage(RemoteMessage message) {
    print('Handling message: ${message.data}');
    if (message.data['screen'] == 'chat') {
      // Requires NavigatorKey in widget tree for navigation
      print('Should navigate to ChatScreen');
    }
  }

  static Future<void> sendNotification(String title, String body) async {
    // Placeholder for server-side sending
    print('Sending notification: $title - $body');
  }
}
