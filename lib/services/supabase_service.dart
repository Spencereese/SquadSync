import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;

/// Supabase service for SquadSync
///
/// Provides dual-client architecture alongside Firebase.
/// Currently being integrated as a complementary data layer.
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

  /// Supabase client instance
  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
          'Supabase not initialized. Call SupabaseService.initialize() first.');
    }
    return Supabase.instance.client;
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
    // Load credentials from environment variables
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception(
          'SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env file');
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
          debugPrint('   JWT Claims: ${claims.keys.toList()}');
          debugPrint('   User role: ${claims['role']}');
          debugPrint('   App metadata: ${claims['app_metadata']}');
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
  }

  /// Check if user is authenticated in Supabase
  static bool get isAuthenticated => client.auth.currentUser != null;

  /// Get current Supabase user
  static User? get currentUser => client.auth.currentUser;

  /// Get current user ID
  static String? get currentUserId => client.auth.currentUser?.id;

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
      redirectTo: 'codsquadapp://auth-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Get current session
  static Session? get currentSession => client.auth.currentSession;

  /// Sign out from Supabase
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Get active channel count
  static int get activeChannelCount => client.getChannels().length;

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
      debugPrint('✅ Removed channel: ${channel.topic}');
    } catch (e) {
      debugPrint('⚠️ Error removing channel ${channel.topic}: $e');
      // Don't throw - this is cleanup, failures are acceptable
    }
  }

  /// Proactively clean up channels approaching rate limit
  /// Returns number of channels cleaned
  static Future<int> cleanupOldChannels() async {
    try {
      final channels = client.getChannels();

      if (channels.length < 80) {
        return 0; // No cleanup needed
      }

      debugPrint('🧹 Proactive cleanup: ${channels.length} channels detected');

      // Remove channels that look old or duplicate
      int cleaned = 0;
      for (final channel in channels) {
        // Remove if topic suggests it's old (can be refined based on your naming)
        if (channel.socket.conn == null) {
          // Disconnected channels
          await safeRemoveChannel(channel);
          cleaned++;
        }
      }

      if (cleaned > 0) {
        debugPrint('✅ Cleaned $cleaned old channels');
      }

      return cleaned;
    } catch (e) {
      debugPrint('⚠️ Error during proactive cleanup: $e');
      return 0;
    }
  }

  /// Dispose of real-time subscriptions
  /// Call this when cleaning up
  static Future<void> dispose() async {
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
final supabase = SupabaseService.client;
