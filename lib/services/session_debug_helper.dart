import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

/// Helper class to debug and verify Supabase session persistence
///
/// Usage in your app:
/// ```dart
/// await SessionDebugHelper.checkSessionPersistence();
/// ```
class SessionDebugHelper {
  /// Check if session is being persisted correctly
  static Future<void> checkSessionPersistence() async {
    if (!kDebugMode) return;

    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📱 SESSION PERSISTENCE CHECK');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (!kIsWeb) {
      debugPrint('Platform: ${Platform.operatingSystem}');
      if (Platform.isIOS) {
        debugPrint('Storage: iOS Keychain (automatic)');
        debugPrint('Entitlements required: keychain-access-groups');
      } else if (Platform.isAndroid) {
        debugPrint('Storage: Android SharedPreferences (automatic)');
      }
    }

    debugPrint('');
    debugPrint('Session Status:');
    if (session != null) {
      debugPrint('  ✅ Active session found');
      debugPrint('  User ID: ${session.user.id}');
      debugPrint('  Has access token: ${session.accessToken.isNotEmpty}');
      debugPrint('  Has refresh token: ${session.refreshToken != null}');
      debugPrint(
          '  Expires At: ${session.expiresAt != null ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000) : "N/A"}');

      // Check if token is expiring soon
      if (session.expiresAt != null) {
        final expiryTime =
            DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        final timeUntilExpiry = expiryTime.difference(DateTime.now());
        debugPrint(
            '  Time until expiry: ${timeUntilExpiry.inHours}h ${timeUntilExpiry.inMinutes % 60}m');

        if (timeUntilExpiry.inHours < 1) {
          debugPrint(
              '  INFO session expiring soon; ensureFreshSession will refresh');
        }
      }
    } else {
      debugPrint('  ❌ No active session');
      debugPrint('  User needs to sign in');
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// Listen for auth state changes (useful for debugging)
  static void setupAuthListener() {
    if (!kDebugMode) return;

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      debugPrint('');
      debugPrint('🔐 AUTH STATE CHANGE: $event');
      if (session != null) {
        debugPrint('   User id: ${session.user.id}');
        debugPrint('   Session active: true');
      } else {
        debugPrint('   Session active: false');
      }
    });

    debugPrint('✅ Auth state listener activated');
  }

  /// Force refresh the current session (useful for testing)
  static Future<void> forceRefreshSession() async {
    try {
      debugPrint('🔄 Forcing session refresh...');
      final response = await Supabase.instance.client.auth.refreshSession();

      if (response.session != null) {
        debugPrint('✅ Session refreshed successfully');
        debugPrint(
            '   New expiry: ${DateTime.fromMillisecondsSinceEpoch(response.session!.expiresAt! * 1000)}');
      } else {
        debugPrint('❌ Session refresh failed - no session returned');
      }
    } catch (e) {
      debugPrint('❌ Session refresh error: $e');
    }
  }

  /// Test session persistence by signing in and checking if it persists
  static Future<void> testSessionPersistence({
    required String email,
    required String password,
  }) async {
    if (!kDebugMode) return;

    debugPrint('');
    debugPrint('🧪 TESTING SESSION PERSISTENCE');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      // Sign in
      debugPrint('1. Signing in...');
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        debugPrint('   ✅ Sign in successful');
        debugPrint('   User id: ${response.session!.user.id}');

        // Wait a moment for storage to persist
        await Future.delayed(const Duration(seconds: 2));

        // Check if session is still there
        debugPrint('');
        debugPrint('2. Checking if session persisted...');
        final currentSession = Supabase.instance.client.auth.currentSession;

        if (currentSession != null) {
          debugPrint('   ✅ Session found in storage');
          debugPrint(
              '   Match: ${currentSession.user.id == response.session!.user.id}');
        } else {
          debugPrint('   ❌ Session NOT found in storage');
          debugPrint('   This indicates a persistence issue!');
        }
      } else {
        debugPrint('   ❌ Sign in failed');
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
