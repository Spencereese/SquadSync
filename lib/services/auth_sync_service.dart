import 'package:logger/logger.dart';

/// Auth sync service - no longer needed with Supabase-only auth
/// Kept for backward compatibility but does nothing
class AuthSyncService {
  final Logger _logger = Logger();

  /// No-op sync method - Supabase is the only auth provider now
  Future<void> syncFirebaseUserToSupabase() async {
    _logger.d('⏭️  Auth sync skipped - using Supabase Auth only');
    return;
  }

  /// No-op sign out method
  Future<void> signOut() async {
    _logger.d('⏭️  Auth sync signOut skipped');
    return;
  }
}
