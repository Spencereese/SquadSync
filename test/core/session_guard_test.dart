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
  });
}
