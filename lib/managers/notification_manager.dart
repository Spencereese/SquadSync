import 'dart:developer' as developer;

import '../core/notification_hygiene.dart';
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

  /// Local display. Pass [type]/[lobbyId]/[gameName] or a [payload] map so
  /// taps can route (peacock must not always send `type=local`).
  Future<void> showNotification({
    required String title,
    required String body,
    String? type,
    String? lobbyId,
    String? gameName,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final merged = payloadFor(
        type: type,
        lobbyId: lobbyId,
        gameName: gameName,
        payload: payload,
      );
      if (NotificationHygieneStore.instance.shouldSuppressShow(merged)) {
        developer.log('Notification hygiene suppressed local show');
        return;
      }
      final hook = showLocal;
      if (hook != null) {
        await hook(title, body, merged);
        return;
      }
      await NotificationService.initialize();
      await NotificationService.showNotification(
        title: title,
        body: body,
        payload: merged,
      );
    } catch (e) {
      developer.log('NotificationManager.showNotification failed: $e');
    }
  }

  static Map<String, dynamic> payloadFor({
    String? type,
    String? lobbyId,
    String? gameName,
    Map<String, dynamic>? payload,
  }) {
    final merged = <String, dynamic>{
      if (payload != null) ...payload,
    };
    merged['type'] = _nonEmpty(type) ?? _nonEmpty(merged['type']) ?? 'local';
    final lobby = _nonEmpty(lobbyId) ??
        _nonEmpty(merged['lobby_id']) ??
        _nonEmpty(merged['lobbyId']);
    final game = _nonEmpty(gameName) ??
        _nonEmpty(merged['game_name']) ??
        _nonEmpty(merged['gameName']);
    if (lobby != null) merged['lobby_id'] = lobby;
    if (game != null) merged['game_name'] = game;
    return merged;
  }

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
