import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

import '../core/app_env.dart';
import '../core/auth_redirect.dart';
import '../core/session_guard.dart';

/// Supabase service for SquadSync
///
/// Primary data layer for auth, realtime, and storage.
///
/// Usage:
/// ```dart
/// final supabase = SupabaseService.client;
///
/// // Query example
/// final response = await supabase
///   .from('lobbies')
///   .select()
///   .eq('id', lobbyId);
///
/// // Real-time subscription
/// supabase
///   .from('chat_messages')
///   .stream(primaryKey: ['id'])
///   .listen((data) => print(data));
/// ```
class SupabaseService {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static bool get isReady =>
      _isInitialized && AppEnv.isSupabaseConfigured;

  /// Null when parked / init was skipped. Never throws.
  static SupabaseClient? get maybeClient {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Live client. Prefer [maybeClient] / [isReady] at call sites that
  /// can run before init (Setup, Auth, AutoMerge).
  static SupabaseClient get client {
    final existing = maybeClient;
    if (existing == null) {
      throw StateError(
          'Supabase not initialized. Call SupabaseService.initialize() first.');
    }
    return existing;
  }

  /// Initialize Supabase
  ///
  /// Call this in main.dart after Firebase initialization:
  /// ```dart
  /// await SupabaseService.initialize();
  /// ```
  ///
  /// Supabase 2.12.0+ supports idempotent initialization - safe to call multiple times
  static Future<void> initialize() async {
    final supabaseUrl = AppEnv.supabaseUrl;
    final supabaseAnonKey = AppEnv.supabaseAnonKey;

    if (!AppEnv.isSupabaseConfigured ||
        supabaseUrl == null ||
        supabaseAnonKey == null) {
      debugPrint(
        'Supabase not configured (empty or placeholder URL). '
        'Client stays offline. flutter run --dart-define-from-file=.env',
      );
      return;
    }

    // Use anon key for proper authentication with RLS
    // Idempotent initialization (2.12.0+): Safe to call multiple times, only initializes once
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      // Storage options for session persistence
      storageOptions: const StorageClientOptions(
        retryAttempts: 10,
      ),
      debug: kDebugMode,
    );

    // Wait for session to restore from storage (iOS Keychain/Android SharedPreferences)
    await Future.delayed(const Duration(milliseconds: 800));

    final session = Supabase.instance.client.auth.currentSession;
    if (kDebugMode) {
      debugPrint('✅ Supabase initialized with authentication');
      debugPrint('   Current session: ${session?.user.id ?? "none"}');

      // NEW in 2.12.0: Get JWT claims for custom claim verification
      if (session != null) {
        try {
          final claimsResponse =
              await Supabase.instance.client.auth.getClaims();
          final claims =
              claimsResponse.claims.claims; // Access claims map via JwtPayload
          debugPrint('   JWT claim keys: ${claims.keys.toList()}');
        } catch (e) {
          debugPrint('   ⚠️ Failed to get JWT claims: $e');
        }
      }

      if (!kIsWeb) {
        debugPrint('   Platform: ${Platform.operatingSystem}');
        if (Platform.isIOS) {
          debugPrint('   iOS: Session persistence via Keychain enabled');
        }
      }
    }

    _isInitialized = true;
    await ensureFreshSession();
  }

  /// Refresh an expired/near-expiry Keychain JWT, or [signOut] so a
  /// dead session cannot keep opening realtime.
  static Future<Session?> ensureFreshSession() async {
    if (!isReady) return null;
    final existing = maybeClient;
    if (existing == null) return null;

    final session = existing.auth.currentSession;
    if (session == null) return null;

    if (!shouldAttemptSessionRefresh(expiresAtSeconds: session.expiresAt)) {
      return session;
    }

    try {
      final response = await existing.auth.refreshSession();
      return response.session;
    } catch (e) {
      debugPrint(
        'Session refresh failed; signing out dead Keychain session: $e',
      );
      try {
        await existing.auth.signOut();
      } catch (signOutError) {
        debugPrint('Sign-out after dead session failed: $signOutError');
      }
      return null;
    }
  }

  /// Check if user is authenticated in Supabase
  static bool get isAuthenticated => isUsableAuthSession(
        hasUser: currentUser != null,
        expiresAtSeconds: currentSession?.expiresAt,
      );

  /// Get current Supabase user
  static User? get currentUser => maybeClient?.auth.currentUser;

  /// Get current user ID
  static String? get currentUserId => currentUser?.id;

  /// Sign in with email and password
  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  /// Sign in with OAuth provider (Google, Apple, etc.)
  static Future<bool> signInWithOAuth({
    required OAuthProvider provider,
    List<AuthFlowType>? scopes,
  }) async {
    return await client.auth.signInWithOAuth(
      provider,
      redirectTo: kSupabaseAuthRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Get current session
  static Session? get currentSession => maybeClient?.auth.currentSession;

  /// Sign out from Supabase
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Get active channel count
  static int get activeChannelCount =>
      maybeClient?.getChannels().length ?? 0;

  /// Check if approaching channel limit
  /// Supabase free tier typically limits to 100 channels per client
  static bool get isApproachingChannelLimit => activeChannelCount > 80;

  /// Log channel usage for debugging
  static void logChannelUsage() {
    final channels = client.getChannels();
    debugPrint('🔔 Active Supabase channels: ${channels.length}');
    if (channels.length > 50) {
      debugPrint('⚠️ High channel count detected. Consider cleanup.');
    }
  }

  /// Safely remove a single channel with error handling
  static Future<void> safeRemoveChannel(RealtimeChannel channel) async {
    try {
      await client.removeChannel(channel);
      debugPrint('✅ Removed channel');
    } catch (e) {
      debugPrint('⚠️ Error removing channel: $e');
      // Don't throw - this is cleanup, failures are acceptable
    }
  }

  /// No-op. Do not nuke sibling typing/lobby/messages/presence channels.
  /// Cap is enforced by single-subscribe + one recovery.
  static Future<int> cleanupOldChannels() async {
    // Never nuke sibling typing/lobby/messages/presence channels.
    // Cap is enforced by single-subscribe + one recovery, not a wipe.
    return 0;
  }

  /// Dispose of real-time subscriptions
  /// Call this when cleaning up
  static Future<void> dispose() async {
    if (maybeClient == null) return;
    try {
      // Clean up any active subscriptions
      final count = activeChannelCount;
      debugPrint('🧹 Cleaning up $count active channels');

      final channels = client.getChannels();
      for (final channel in channels) {
        await safeRemoveChannel(channel);
      }

      debugPrint('✅ Cleaned up all channels');
    } catch (e) {
      debugPrint('⚠️ Error during channel cleanup: $e');
      // Don't throw - this is cleanup, failures are acceptable
    }
  }
}

/// Convenience getter for Supabase client
///
/// Usage:
/// ```dart
/// final data = await supabase.from('table').select();
/// ```
SupabaseClient get supabase => SupabaseService.client;
