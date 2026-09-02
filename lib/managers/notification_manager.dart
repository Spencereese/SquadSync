import '../notification_service.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';

class NotificationManager {
  /// Test hook. Production shows via [NotificationService] /
  /// FlutterLocalNotificationsPlugin (same channel as foreground FCM).
  static Future<void> Function(
    String title,
    String body,
    Map<String, dynamic> payload,
  )? showLocal;

  Future<void> updateFCMToken(String token) async {
    final user = AuthServiceSupabase().currentUser;
    if (user != null) {
      await SupabaseService.client.from('users').update({
        'fcm_token': token,
        'last_token_update': DateTime.now().toIso8601String(),
      }).eq('uid', user.id);
    }
  }

  Future<String?> getFCMToken() async {
    final user = AuthServiceSupabase().currentUser;
    if (user != null) {
      final response = await SupabaseService.client
          .from('users')
          .select('fcm_token')
          .eq('uid', user.id)
          .maybeSingle();
      return response?['fcm_token'] as String?;
    }
    return null;
  }

  Future<void> showNotification(
      {required String title, required String body}) async {
    final payload = <String, dynamic>{'type': 'local'};
    final hook = showLocal;
    if (hook != null) {
      await hook(title, body, payload);
      return;
    }
    await NotificationService.showNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }
}
