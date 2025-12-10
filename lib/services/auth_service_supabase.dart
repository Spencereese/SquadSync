import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

/// Supabase Auth Service for SquadSync
///
/// Replaces Firebase Auth as the primary authentication system.
/// Stores Firebase UID in user metadata for backward compatibility with existing RLS policies.
///
/// Usage:
/// ```dart
/// final authService = AuthServiceSupabase();
///
/// // Sign in
/// await authService.signInWithEmailPassword(
///   email: 'user@example.com',
///   password: 'password123',
/// );
///
/// // Get current user
/// final user = authService.currentUser;
/// final firebaseUid = authService.currentFirebaseUid;
/// ```
class AuthServiceSupabase {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Get current user ID (Supabase UID)
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Get current user's UID (Supabase UUID)
  String? get currentFirebaseUid {
    // For backward compatibility, return Supabase UID
    return currentUser?.id;
  }

  /// Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('✅ Signed in: ${response.user?.id}');
      }
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign in error: $e');
      }
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName ?? email.split('@')[0],
          'email': email,
        },
      );

      if (kDebugMode) {
        print('✅ Signed up: ${response.user?.id}');
      }
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign up error: $e');
      }
      rethrow;
    }
  }

  /// Sign in with Google (OAuth)
  Future<bool> signInWithGoogle() async {
    try {
      final result = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'codsquadapp://auth-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      if (kDebugMode) {
        print('✅ Google sign-in initiated');
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Google sign-in error: $e');
      }
      rethrow;
    }
  }

  /// Sign in with Apple (OAuth)
  Future<bool> signInWithApple() async {
    try {
      final result = await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'codsquadapp://auth-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      // Ensure Firebase UID is set for backward compatibility
      if (_supabase.auth.currentUser != null) {
        await _ensureFirebaseUidInMetadata(_supabase.auth.currentUser!);
      }

      if (kDebugMode) {
        print('✅ Apple sign-in initiated');
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Apple sign-in error: $e');
      }
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      if (kDebugMode) {
        print('✅ Signed out');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign out error: $e');
      }
      rethrow;
    }
  }

  /// Ensures Firebase UID exists in user metadata for backward compatibility
  /// If not, generates a new one and updates the user metadata
  Future<void> _ensureFirebaseUidInMetadata(User user) async {
    try {
      // Check if Firebase UID already exists
      final existingUid = user.userMetadata?['firebase_uid'];
      if (existingUid != null) {
        return; // Already has Firebase UID
      }

      // Generate new Firebase UID
      final newFirebaseUid = _generateFirebaseUid();

      // Update user metadata
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'firebase_uid': newFirebaseUid,
          },
        ),
      );

      if (kDebugMode) {
        print('✅ Added Firebase UID to user metadata: $newFirebaseUid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to update user metadata: $e');
      }
    }
  }

  /// Generate a Firebase-compatible UID (28 characters alphanumeric)
  /// Firebase UIDs are 28 characters of alphanumeric characters
  String _generateFirebaseUid() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
          28, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Auth state changes stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Reset password
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Update user profile
  Future<UserResponse> updateProfile({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    return await _supabase.auth.updateUser(
      UserAttributes(
        data: {
          if (displayName != null) 'display_name': displayName,
          if (photoUrl != null) 'photo_url': photoUrl,
          ...?additionalData,
        },
      ),
    );
  }
}
