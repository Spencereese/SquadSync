import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
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
  static final Logger _logger = Logger();

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
        _logger.i('✅ Signed in: ${response.user?.id}');
      }
      return response;
    } catch (e) {
      if (kDebugMode) {
        _logger.e('❌ Sign in error: $e');
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
        _logger.i('✅ Signed up: ${response.user?.id}');
      }
      return response;
    } catch (e) {
      if (kDebugMode) {
        _logger.e('❌ Sign up error: $e');
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
        _logger.i('✅ Google sign-in initiated');
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        _logger.e('❌ Google sign-in error: $e');
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
        _logger.i('✅ Apple sign-in initiated');
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        _logger.e('❌ Apple sign-in error: $e');
      }
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      if (kDebugMode) {
        _logger.i('✅ Signed out');
      }
    } catch (e) {
      if (kDebugMode) {
        _logger.e('❌ Sign out error: $e');
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
        _logger.i('✅ Added Firebase UID to user metadata: $newFirebaseUid');
      }
    } catch (e) {
      if (kDebugMode) {
        _logger.w('⚠️ Failed to update user metadata: $e');
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

  /// Get JWT claims from current session (NEW in Supabase 2.12.0)
  ///
  /// Returns decoded JWT claims including:
  /// - user_metadata: Custom user data
  /// - app_metadata: Application metadata (roles, etc.)
  /// - role: User's role (authenticated, anon, etc.)
  /// - aud: Audience claim
  /// - exp: Expiration timestamp
  ///
  /// Usage:
  /// ```dart
  /// final claims = authService.getJWTClaims();
  /// final userRole = claims?['role'];
  /// final customClaim = claims?['app_metadata']?['custom_claim'];
  ///
  /// // Verify custom claims
  /// if (claims?['app_metadata']?['is_admin'] == true) {
  ///   // User has admin privileges
  /// }
  /// ```
  Future<Map<String, dynamic>?> getJWTClaims() async {
    try {
      final claimsResponse = await _supabase.auth.getClaims();
      final claims =
          claimsResponse.claims.claims; // Access claims map via JwtPayload

      if (kDebugMode) {
        _logger.d('🔐 JWT Claims retrieved:');
        _logger.d('   Role: ${claims['role']}');
        _logger
            .d('   User ID: ${claimsResponse.claims.sub}'); // Direct property
        _logger.d('   Email: ${claims['email']}');
        _logger.d('   App Metadata: ${claims['app_metadata']}');
        _logger.d('   User Metadata: ${claims['user_metadata']}');

        // Check expiration
        final exp = claimsResponse.claims.exp; // Direct property
        if (exp != null) {
          final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          final timeRemaining = expiryDate.difference(DateTime.now());
          _logger.d('   Token expires in: ${timeRemaining.inMinutes} minutes');
        }
      }

      return claims;
    } catch (e) {
      if (kDebugMode) {
        _logger.w('⚠️ Failed to get JWT claims: $e');
      }
      return null;
    }
  }

  /// Verify custom claim from JWT (NEW in Supabase 2.12.0)
  ///
  /// Checks if a custom claim exists in app_metadata or user_metadata
  ///
  /// Usage:
  /// ```dart
  /// // Check if user is admin
  /// final isAdmin = authService.verifyCustomClaim('app_metadata', 'is_admin');
  ///
  /// // Check if user has specific permission
  /// final hasPermission = authService.verifyCustomClaim('app_metadata', 'permissions', 'write');
  /// ```
  Future<bool> verifyCustomClaim(String metadataType, String claimKey,
      [dynamic expectedValue]) async {
    final claims = await getJWTClaims();
    if (claims == null) return false;

    final metadata = claims[metadataType];
    if (metadata == null) return false;

    final claimValue = metadata[claimKey];

    // If no expected value provided, just check if claim exists
    if (expectedValue == null) {
      return claimValue != null;
    }

    // Compare with expected value
    return claimValue == expectedValue;
  }

  /// Get user role from JWT claims (NEW in Supabase 2.12.0)
  Future<String?> getUserRole() async {
    final claims = await getJWTClaims();
    return claims?['role'] as String?;
  }
}
