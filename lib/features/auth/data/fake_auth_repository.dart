import 'dart:async';

import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/auth/data/auth_repository.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';

/// In-memory sign-in. [fail] rejects the next call. A code shorter than 6
/// digits is rejected so widget tests can show the error.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.fail = false, AuthUser? signedIn})
    : _user = signedIn;

  bool fail;
  AuthUser? _user;
  final _updates = StreamController<AuthUser?>.broadcast();
  final _refreshes = StreamController<void>.broadcast();

  String? lastEmail;
  String? lastCode;
  var sendCount = 0;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<void> watchTokenRefresh() => _refreshes.stream;

  /// Test seam. A successful silent refresh. Does not sign the person out.
  void tokenRefresh() {
    if (!_refreshes.isClosed) _refreshes.add(null);
  }

  @override
  Stream<AuthUser?> watchUser() async* {
    yield _user;
    yield* _updates.stream;
  }

  @override
  Future<void> sendEmailCode(String email) async {
    if (fail) throw const RepositoryFailure('send code failed');
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw const RepositoryFailure('Enter an email.');
    }
    lastEmail = trimmed;
    sendCount += 1;
  }

  /// Test seam. Switches the signed-in person without a code.
  void restore(AuthUser? user) {
    _user = user;
    _updates.add(user);
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    if (fail) throw const RepositoryFailure('verify failed');
    final trimmed = code.trim();
    if (trimmed.length < 6) {
      throw const RepositoryFailure('code rejected');
    }
    lastCode = trimmed;
    _user = AuthUser(id: 'signed-in', email: email.trim());
    _updates.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _updates.add(null);
  }
}
