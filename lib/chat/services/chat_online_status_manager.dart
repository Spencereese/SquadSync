import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for managing user online status
class ChatOnlineStatusManager {
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  /// Update user's online status in Supabase
  /// Respects user's privacy setting for showing online status
  void updateOnlineStatus(bool isOnline,
      {String? displayName, String? profileImage}) async {
    String? uid = _authService.currentUser?.id;
    if (uid != null) {
      String finalDisplayName = displayName ?? '';
      if (finalDisplayName == 'User' || finalDisplayName.isEmpty) {
        finalDisplayName = _authService
                .currentUser?.userMetadata?['display_name'] as String? ??
            'Anonymous';
      }

      // Check user's privacy setting for showing online status
      bool shouldShowOnline = isOnline;
      try {
        final userResponse = await SupabaseService.client
            .from('users')
            .select('notification_settings')
            .eq('uid', uid)
            .single();

        final notificationSettings =
            userResponse['notification_settings'] as Map<String, dynamic>?;
        final showOnlineStatus =
            notificationSettings?['showOnlineStatus'] as bool? ?? true;

        // If user has disabled online status, always show as offline
        if (!showOnlineStatus) {
          shouldShowOnline = false;
          debugPrint('Online status hidden by user privacy setting');
        }
      } catch (e) {
        debugPrint('Error checking online status setting: $e');
        // Continue with default behavior if we can\'t check the setting
      }

      debugPrint(
          'Updating online status: uid=$uid, displayName=$finalDisplayName, online=$shouldShowOnline');
      SupabaseService.client
          .from('users')
          .update({
            'display_name': finalDisplayName,
            'photo_url': profileImage, // Changed from profile_image
            'last_online': DateTime.now().toIso8601String(),
            'online': shouldShowOnline,
          })
          .eq('uid', uid) // Changed from 'id' to 'uid'
          .then((_) {
            debugPrint('Online status updated successfully');
          })
          .catchError((error) {
            debugPrint('Error updating online status: $error');
          });
    } else {
      debugPrint('No authenticated user');
    }
  }
}
