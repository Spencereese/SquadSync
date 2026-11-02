import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/auth/data/auth_repository.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

/// Email OTP, not a magic link. The code is typed in the app, so sign-in
/// does not depend on a deep link. The dashboard template still has to
/// include {{ .Token }} before this works against a live project.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> watchUser() async* {
    yield currentUser;
    yield* _auth.onAuthStateChange.map((state) => _map(state.session?.user));
  }

  @override
  Future<void> sendEmailCode(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw const RepositoryFailure('Enter an email.');
    }
    try {
      await _auth.signInWithOtp(email: trimmed);
    } on AuthException catch (error) {
      throw RepositoryFailure(error.message);
    }
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      await _auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.email,
      );
    } on AuthException catch (error) {
      throw RepositoryFailure(error.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (error) {
      throw RepositoryFailure(error.message);
    }
  }
}

AuthUser? _map(User? user) {
  if (user == null) return null;
  return AuthUser(id: user.id, email: user.email);
}
