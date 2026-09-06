import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/core/session_guard.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/services/supabase_service.dart';

void main() {
  test('expired expiresAt is rejected', () {
    expect(isSessionExpired(expiresAtSeconds: 1), isTrue);
    expect(isSessionExpired(expiresAtSeconds: null), isTrue);
    expect(
      isSessionExpired(expiresAtSeconds: 4102444800),
      isFalse,
    );
  });

  test('usable session requires a user and a live JWT', () {
    expect(
      isUsableAuthSession(hasUser: true, expiresAtSeconds: 1),
      isFalse,
    );
    expect(
      isUsableAuthSession(hasUser: false, expiresAtSeconds: 4102444800),
      isFalse,
    );
    expect(
      isUsableAuthSession(hasUser: true, expiresAtSeconds: 4102444800),
      isTrue,
    );
  });

  test('near-expiry tokens request a refresh', () {
    final now = DateTime.utc(2026, 1, 1);
    final inTwoMinutes = now.add(const Duration(minutes: 2)).millisecondsSinceEpoch ~/ 1000;
    expect(
      shouldAttemptSessionRefresh(expiresAtSeconds: inTwoMinutes, now: now),
      isTrue,
    );
    final inAnHour = now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    expect(
      shouldAttemptSessionRefresh(expiresAtSeconds: inAnHour, now: now),
      isFalse,
    );
    final inSevenMinutes =
        now.add(const Duration(minutes: 7)).millisecondsSinceEpoch ~/ 1000;
    expect(
      shouldAttemptSessionRefresh(expiresAtSeconds: inSevenMinutes, now: now),
      isTrue,
    );
    final inTwentyMinutes =
        now.add(const Duration(minutes: 20)).millisecondsSinceEpoch ~/ 1000;
    expect(
      shouldAttemptSessionRefresh(expiresAtSeconds: inTwentyMinutes, now: now),
      isFalse,
    );
  });

  test('currentUser is null when Supabase is unconfigured', () {
    AppEnv.debugReplaceForTest({
      'SUPABASE_URL': 'https://your-project.supabase.co',
      'SUPABASE_ANON_KEY': 'your_anon_key',
    });
    addTearDown(() => AppEnv.debugReplaceForTest({}));

    expect(AppEnv.isSupabaseConfigured, isFalse);
    expect(SupabaseService.isInitialized, isFalse);
    expect(AuthServiceSupabase().currentUser, isNull);
    expect(AuthServiceSupabase().currentSession, isNull);
    expect(SupabaseService.currentUser, isNull);
    expect(SupabaseService.maybeClient, isNull);
    expect(SupabaseService.currentSession, isNull);
    expect(SupabaseService.isAuthenticated, isFalse);
  });

  group('Keychain restore + cold-start sign-in', () {
    final now = DateTime.utc(2026, 1, 1);
    final liveExp =
        now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final nearExp =
        now.add(const Duration(minutes: 7)).millisecondsSinceEpoch ~/ 1000;

    test('missing session is empty sign-in, not a crash', () {
      expect(
        resolveSessionRestorePhase(
          isConfigured: true,
          isInitialized: true,
          hasUser: false,
          expiresAtSeconds: liveExp,
          now: now,
        ),
        SessionRestorePhase.missing,
      );
      expect(
        sessionRestoreRedirect(
          phase: SessionRestorePhase.missing,
          currentLocation: '/',
        ),
        kSessionRestoreSignInRoute,
      );
      expect(
        sessionRestoreRedirect(
          phase: SessionRestorePhase.missing,
          currentLocation: '/setup',
        ),
        isNull,
      );
      expect(
        sessionRestoreMessage(SessionRestorePhase.missing),
        kSessionMissingCopy,
      );
      expect(
        sessionRestoreFeedbackKey(SessionRestorePhase.missing),
        const Key('session-restore-missing'),
      );
      expect(sessionRestoreHint(SessionRestorePhase.missing), isNull);
    });

    test('expired session is sign-in, not a live JWT', () {
      expect(
        resolveSessionRestorePhase(
          isConfigured: true,
          isInitialized: true,
          hasUser: true,
          expiresAtSeconds: 1,
          now: now,
        ),
        SessionRestorePhase.expired,
      );
      expect(
        resolveSessionRestorePhase(
          isConfigured: true,
          isInitialized: true,
          hasUser: true,
          expiresAtSeconds: null,
          now: now,
        ),
        SessionRestorePhase.expired,
      );
      expect(
        sessionRestoreRedirect(
          phase: SessionRestorePhase.expired,
          currentLocation: '/squad?lobby_id=lobby-9',
        ),
        kSessionRestoreSignInRoute,
      );
      expect(
        sessionRestoreMessage(SessionRestorePhase.expired),
        kSessionExpiredCopy,
      );
      expect(
        sessionRestoreHint(SessionRestorePhase.expired),
        kSessionRestoreFailedHint,
      );
      expect(
        sessionRestoreShouldAttemptRefresh(SessionRestorePhase.expired),
        isTrue,
      );
    });

    test('Keychain restore failure is error, not a crash', () {
      expect(
        resolveSessionRestorePhase(
          isConfigured: true,
          isInitialized: true,
          hasUser: true,
          expiresAtSeconds: liveExp,
          restoreError: StateError('Keychain locked'),
          now: now,
        ),
        SessionRestorePhase.restoreFailed,
      );
      expect(
        sessionRestoreRedirect(
          phase: SessionRestorePhase.restoreFailed,
          currentLocation: '/',
        ),
        kSessionRestoreSignInRoute,
      );
      expect(
        sessionRestoreMessage(SessionRestorePhase.restoreFailed),
        kSessionRestoreFailedCopy,
      );
      expect(
        sessionRestoreHint(SessionRestorePhase.restoreFailed),
        kSessionRestoreFailedHint,
      );
      expect(
        sessionRestoreFeedbackKey(SessionRestorePhase.restoreFailed),
        const Key('session-restore-failed'),
      );
      expect(
        sessionRestoreShouldAttemptRefresh(SessionRestorePhase.restoreFailed),
        isFalse,
      );
    });

    test('cold open without session lands on setup and does not throw', () {
      expect(
        () => restoreSessionOnColdOpen(
          isConfigured: true,
          isInitialized: true,
          readHasUser: () => false,
          readExpiresAtSeconds: () => null,
        ),
        returnsNormally,
      );
      final missing = restoreSessionOnColdOpen(
        isConfigured: true,
        isInitialized: true,
        readHasUser: () => false,
        readExpiresAtSeconds: () => null,
      );
      expect(missing.phase, SessionRestorePhase.missing);
      expect(missing.redirectTo, kSessionRestoreSignInRoute);
      expect(missing.crashes, isFalse);
      expect(missing.isSignedOut, isTrue);
      expect(sessionRestoreAllowsColdOpen(missing.phase), isTrue);
    });

    test('cold open Keychain throw lands on setup and does not throw', () {
      expect(
        () => restoreSessionOnColdOpen(
          isConfigured: true,
          isInitialized: true,
          readHasUser: () => throw StateError('Keychain locked'),
          readExpiresAtSeconds: () => throw StateError('Keychain locked'),
        ),
        returnsNormally,
      );
      final failed = restoreSessionOnColdOpen(
        isConfigured: true,
        isInitialized: true,
        readHasUser: () => throw StateError('Keychain locked'),
        readExpiresAtSeconds: () => 1,
      );
      expect(failed.phase, SessionRestorePhase.restoreFailed);
      expect(failed.redirectTo, kSessionRestoreSignInRoute);
      expect(failed.crashes, isFalse);
      expect(failed.error, isA<StateError>());
    });

    test('cold open expired JWT lands on setup', () {
      final expired = restoreSessionOnColdOpen(
        isConfigured: true,
        isInitialized: true,
        readHasUser: () => true,
        readExpiresAtSeconds: () => 1,
        now: now,
      );
      expect(expired.phase, SessionRestorePhase.expired);
      expect(expired.redirectTo, kSessionRestoreSignInRoute);
      expect(expired.crashes, isFalse);
    });

    test('readStoredSessionSafely swallows Keychain throw', () {
      expect(
        readStoredSessionSafely<int>(() => throw Exception('Keychain locked')),
        isNull,
      );
      Object? seen;
      expect(
        readStoredSessionSafely<String>(
          () => throw StateError('no access group'),
          onError: (e) => seen = e,
        ),
        isNull,
      );
      expect(seen, isA<StateError>());
      expect(readStoredSessionSafely(() => 42), 42);
    });

    test('unconfigured cold open is sign-in, not a hang', () {
      final parked = restoreSessionOnColdOpen(
        isConfigured: false,
        isInitialized: false,
        readHasUser: () => false,
        readExpiresAtSeconds: () => null,
      );
      expect(parked.phase, SessionRestorePhase.unconfigured);
      expect(parked.redirectTo, kSessionRestoreSignInRoute);
      expect(parked.crashes, isFalse);
      expect(
        sessionRestoreMessage(SessionRestorePhase.unconfigured),
        kSessionUnconfiguredCopy,
      );
    });

    test('usable session on setup redirects home; on home stays', () {
      expect(
        resolveSessionRestorePhase(
          isConfigured: true,
          isInitialized: true,
          hasUser: true,
          expiresAtSeconds: liveExp,
          now: now,
        ),
        SessionRestorePhase.usable,
      );
      expect(
        sessionRestoreRedirect(
          phase: SessionRestorePhase.usable,
          currentLocation: '/setup',
        ),
        kSessionRestoreHomeRoute,
      );
      expect(
        sessionRestoreRedirect(
          phase: SessionRestorePhase.usable,
          currentLocation: '/',
        ),
        isNull,
      );
    });

    test('near-expiry is needsRefresh, not expired', () {
      expect(
        resolveSessionRestorePhase(
          isConfigured: true,
          isInitialized: true,
          hasUser: true,
          expiresAtSeconds: nearExp,
          now: now,
        ),
        SessionRestorePhase.needsRefresh,
      );
      expect(
        sessionRestoreShouldAttemptRefresh(SessionRestorePhase.needsRefresh),
        isTrue,
      );
      expect(
        sessionRestoreRedirect(
          phase: SessionRestorePhase.needsRefresh,
          currentLocation: '/setup',
        ),
        kSessionRestoreHomeRoute,
      );
      final result = reduceSessionRestore(
        isConfigured: true,
        isInitialized: true,
        hasUser: true,
        expiresAtSeconds: nearExp,
        currentLocation: '/',
        now: now,
      );
      expect(result.phase, SessionRestorePhase.needsRefresh);
      expect(result.isUsable, isTrue);
      expect(result.redirectTo, isNull);
    });

    test('every restore phase allows cold open without crash', () {
      for (final phase in SessionRestorePhase.values) {
        expect(sessionRestoreAllowsColdOpen(phase), isTrue);
        expect(
          () => sessionRestoreRedirect(phase: phase, currentLocation: '/'),
          returnsNormally,
        );
        expect(
          () => sessionRestoreMessage(phase),
          returnsNormally,
        );
        expect(
          reduceSessionRestore(
            isConfigured: phase != SessionRestorePhase.unconfigured,
            isInitialized: phase != SessionRestorePhase.unconfigured,
            hasUser: phase == SessionRestorePhase.usable ||
                phase == SessionRestorePhase.needsRefresh ||
                phase == SessionRestorePhase.expired,
            expiresAtSeconds: phase == SessionRestorePhase.expired ? 1 : liveExp,
            restoreError: phase == SessionRestorePhase.restoreFailed
                ? Exception('Keychain locked')
                : null,
            currentLocation: '/',
            now: now,
          ).crashes,
          isFalse,
        );
      }
    });
  });
}
