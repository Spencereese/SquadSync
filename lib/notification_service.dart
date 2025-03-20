import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Request permission (required for iOS, optional Android)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.notification?.title} - ${message.notification?.body}');
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // Get FCM token for targeting specific devices (optional)
    String? token = await _messaging.getToken();
    print('FCM Token: $token');
  }

  static Future<void> _backgroundHandler(RemoteMessage message) async {
    print('Background message: ${message.notification?.title} - ${message.notification?.body}');
  }

  static Future<void> sendNotification(String title, String body) async {
    // For testing, send via FCM token or topic (requires server setup)
    // This is a placeholder—real implementation needs a server
    print('Sending notification: $title - $body');
  }
}