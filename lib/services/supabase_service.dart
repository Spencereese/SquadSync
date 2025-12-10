import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
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
///   .from('squads')
///   .select()
///   .eq('id', squadId);
///
/// // Real-time subscription
/// supabase
///   .from('chat_messages')
///   .stream(primaryKey: ['id'])
///   .listen((data) => print(data));
/// ```
class SupabaseService {
  /// Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase
  ///
  /// Call this in main.dart after Firebase initialization:
  /// ```dart
  /// await SupabaseService.initialize();
  /// ```
  static Future<void> initialize() async {
    // Use anon key for proper authentication with RLS
    await Supabase.initialize(
      url: 'https://sfckxrnoiwetmzdycqaa.supabase.co',
      anonKey: _anonKey,
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
      if (!kIsWeb) {
        debugPrint('   Platform: ${Platform.operatingSystem}');
        if (Platform.isIOS) {
          debugPrint('   iOS: Session persistence via Keychain enabled');
        }
      }
    }
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

  /// Dispose of real-time subscriptions
  /// Call this when cleaning up
  static void dispose() {
    // Clean up any active subscriptions
    client.removeAllChannels();
  }

  // Supabase anon key for client-side authentication with RLS
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNmY2t4cm5vaXdldG16ZHljcWFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MDEzMzUsImV4cCI6MjA4MDQ3NzMzNX0.9SZ_HD8SV_-BAz2uYptHohHmOcS6TaF_4JUD5Sl__qA';
}

/// Convenience getter for Supabase client
///
/// Usage:
/// ```dart
/// final data = await supabase.from('table').select();
/// ```
final supabase = SupabaseService.client;
