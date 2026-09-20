import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// JWT Validation Helper for Supabase Authentication
///
/// Provides utilities to validate JWT tokens and extract claims
/// for secure server-side operations and RLS policy enforcement.
///
/// Usage:
/// ```dart
/// // Check if user is authenticated
/// if (!JwtValidator.isAuthenticated()) {
///   throw UnauthorizedException();
/// }
///
/// // Get current user ID
/// final userId = JwtValidator.getCurrentUserId();
///
/// // Validate token hasn't expired
/// if (!JwtValidator.isTokenValid()) {
///   await _refreshSession();
/// }
/// ```
class JwtValidator {
  /// Get current session from Supabase
  static Session? get _currentSession =>
      SupabaseService.maybeClient?.auth.currentSession;

  /// Check if user is authenticated (has valid JWT)
  static bool isAuthenticated() {
    return _currentSession != null && isTokenValid();
  }

  /// Get current user ID from JWT
  static String? getCurrentUserId() {
    return _currentSession?.user.id;
  }

  /// Get current user email from JWT
  static String? getCurrentUserEmail() {
    return _currentSession?.user.email;
  }

  /// Get user role from JWT claims
  static String? getUserRole() {
    return _currentSession?.user.role;
  }

  /// Check if token is expired
  static bool isTokenValid() {
    final session = _currentSession;
    if (session == null) return false;

    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;

    return DateTime.now().millisecondsSinceEpoch < expiresAt * 1000;
  }

  /// Get time until token expires (in seconds)
  static int? getTimeUntilExpiry() {
    final session = _currentSession;
    if (session == null) return null;

    final expiresAt = session.expiresAt;
    if (expiresAt == null) return null;

    final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final now = DateTime.now();

    return expiryTime.difference(now).inSeconds;
  }

  /// Check if token should be refreshed (expires in less than 5 minutes)
  static bool shouldRefreshToken() {
    final timeUntilExpiry = getTimeUntilExpiry();
    if (timeUntilExpiry == null) return true;

    return timeUntilExpiry < 300; // 5 minutes
  }

  /// Get all JWT claims as map
  static Map<String, dynamic>? getJwtClaims() {
    final session = _currentSession;
    if (session == null) return null;

    return {
      'sub': session.user.id,
      'email': session.user.email,
      'role': session.user.role,
      'aud': session.user.aud,
      'exp': session.expiresAt,
      'iat': session.user.createdAt,
    };
  }

  /// Validate JWT and throw exception if invalid
  static void requireAuthentication() {
    if (!isAuthenticated()) {
      throw UnauthorizedException('Authentication required');
    }
  }

  /// Validate JWT and check if user has specific role
  static void requireRole(String requiredRole) {
    requireAuthentication();

    final role = getUserRole();
    if (role != requiredRole) {
      throw UnauthorizedException(
          'Insufficient permissions. Required role: $requiredRole');
    }
  }

  /// Validate JWT and check if user owns resource
  static void requireOwnership(String? resourceOwnerId) {
    requireAuthentication();

    final currentUserId = getCurrentUserId();
    if (currentUserId != resourceOwnerId) {
      throw UnauthorizedException(
          'You do not have permission to access this resource');
    }
  }

  /// Validate JWT and check if user is member of lobby
  static Future<void> requireLobbyMembership(String lobbyId) async {
    requireAuthentication();

    final userId = getCurrentUserId();
    final supabase = SupabaseService.maybeClient;
    if (supabase == null) {
      throw UnauthorizedException(
        'Supabase client is not initialized. '
        'Override supabaseClientProvider or inject a client in tests.',
      );
    }

    try {
      final response = await supabase
          .from('lobbies')
          .select('creator_uid, member_uids')
          .eq('id', lobbyId)
          .single();

      final creatorUid = response['creator_uid'] as String;
      final memberUids = (response['member_uids'] as List).cast<String>();

      if (creatorUid != userId && !memberUids.contains(userId)) {
        throw UnauthorizedException('You are not a member of this lobby');
      }
    } catch (e) {
      if (e is UnauthorizedException) rethrow;
      throw UnauthorizedException('Failed to validate lobby membership: $e');
    }
  }

  /// Debug helper to log JWT information
  static void debugLogJwt() {
    if (!kDebugMode) return;

    final claims = getJwtClaims();
    if (claims == null) {
      debugPrint('❌ No JWT token found');
      return;
    }

    debugPrint('🔐 JWT Token Info:');
    debugPrint('   User ID: ${claims['sub']}');
    debugPrint('   Role: ${claims['role']}');
    debugPrint('   Expires in: ${getTimeUntilExpiry()} seconds');
    debugPrint('   Should refresh: ${shouldRefreshToken()}');
  }
}

/// Exception thrown when JWT validation fails
class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException([this.message = 'Unauthorized']);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Mixin to add JWT validation to data sources
mixin JwtValidationMixin {
  /// Validate JWT before performing operation
  void validateJwt() {
    JwtValidator.requireAuthentication();
  }

  /// Get current user ID with validation
  String getAuthenticatedUserId() {
    JwtValidator.requireAuthentication();
    return JwtValidator.getCurrentUserId()!;
  }

  /// Validate ownership of resource
  void validateOwnership(String? resourceOwnerId) {
    JwtValidator.requireOwnership(resourceOwnerId);
  }

  /// Validate lobby membership
  Future<void> validateLobbyMembership(String lobbyId) async {
    await JwtValidator.requireLobbyMembership(lobbyId);
  }
}
