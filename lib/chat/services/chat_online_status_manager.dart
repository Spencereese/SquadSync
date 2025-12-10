import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for managing user online status
class ChatOnlineStatusManager {
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  /// Update user's online status in Supabase
  void updateOnlineStatus(bool isOnline,
      {String? displayName, String? profileImage}) {
    String? uid = _authService.currentUser?.id;
    if (uid != null) {
      String finalDisplayName = displayName ?? '';
      if (finalDisplayName == 'User' || finalDisplayName.isEmpty) {
        finalDisplayName = _authService
                .currentUser?.userMetadata?['display_name'] as String? ??
            'Anonymous';
      }
      debugPrint(
          'Updating online status: uid=$uid, displayName=$finalDisplayName');
      SupabaseService.client
          .from('users')
          .update({
            'display_name': finalDisplayName,
            'profile_image': profileImage,
            'last_online': DateTime.now().toIso8601String(),
            'online': isOnline,
          })
          .eq('id', uid)
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
