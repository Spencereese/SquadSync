import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';

class NotificationManager {
  Future<void> updateFCMToken(String token) async {
    final user = AuthServiceSupabase().currentUser;
    if (user != null) {
      await SupabaseService.client.from('users').update({
        'fcm_token': token,
        'last_token_update': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    }
  }

  Future<String?> getFCMToken() async {
    final user = AuthServiceSupabase().currentUser;
    if (user != null) {
      final response = await SupabaseService.client
          .from('users')
          .select('fcm_token')
          .eq('id', user.id)
          .maybeSingle();
      return response?['fcm_token'] as String?;
    }
    return null;
  }

  Future<void> showNotification(
      {required String title, required String body}) async {
    // TODO: Implement local notification display
    // This would integrate with flutter_local_notifications
  }
}
