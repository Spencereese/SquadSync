import 'package:squadsync/features/auth/domain/auth_user.dart';

/// Email one-time code. No password, and no magic-link redirect.
abstract class AuthRepository {
  AuthUser? get currentUser;

  Stream<AuthUser?> watchUser();

  /// Fires when the access token was refreshed and the session is still valid.
  /// A failed refresh shows up as [watchUser] emitting null, not as this stream.
  Stream<void> watchTokenRefresh();

  Future<void> sendEmailCode(String email);

  Future<void> verifyEmailCode({required String email, required String code});

  Future<void> signOut();
}
