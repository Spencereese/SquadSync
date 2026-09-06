import 'package:flutter/foundation.dart';

/// Pure session expiry / Keychain restore checks. No Supabase imports so
/// unit tests stay light.

const kSessionRestoreSignInRoute = '/setup';
const kSessionRestoreHomeRoute = '/';

const kSessionMissingCopy = 'Sign in to continue';
const kSessionExpiredCopy = 'Session expired. Sign in again.';
const kSessionRestoreFailedCopy = "Couldn't restore your session";
const kSessionRestoreFailedHint = 'Sign in again.';
const kSessionUnconfiguredCopy = 'Sign in is unavailable.';

/// Cold-start / Keychain restore. Missing and expired are empty (sign-in).
/// Keychain throw is error. Never a crash.
enum SessionRestorePhase {
  unconfigured,
  missing,
  expired,
  restoreFailed,
  needsRefresh,
  usable,
}

class SessionRestoreResult {
  const SessionRestoreResult({
    required this.phase,
    this.redirectTo,
    this.error,
  });

  final SessionRestorePhase phase;
  final String? redirectTo;
  final Object? error;

  bool get crashes => false;
  bool get isUsable =>
      phase == SessionRestorePhase.usable ||
      phase == SessionRestorePhase.needsRefresh;
  bool get isSignedOut => !isUsable;
}

bool isSessionExpired({
  required int? expiresAtSeconds,
  DateTime? now,
}) {
  if (expiresAtSeconds == null) return true;
  final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds * 1000);
  return !(now ?? DateTime.now()).isBefore(expiry);
}

/// Refresh if [expiresAtSeconds] is missing, already expired, or inside
/// [refreshWindow] of expiry. Default 10m so a ~7m remaining JWT refreshes
/// before InvalidJWT (do not wait for the token to die).
bool shouldAttemptSessionRefresh({
  required int? expiresAtSeconds,
  DateTime? now,
  Duration refreshWindow = const Duration(minutes: 10),
}) {
  if (expiresAtSeconds == null) return true;
  final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds * 1000);
  final t = now ?? DateTime.now();
  return !t.add(refreshWindow).isBefore(expiry);
}

/// A user object alone is not signed-in if the JWT is dead.
bool isUsableAuthSession({
  required bool hasUser,
  required int? expiresAtSeconds,
  DateTime? now,
}) {
  if (!hasUser) return false;
  return !isSessionExpired(expiresAtSeconds: expiresAtSeconds, now: now);
}

/// Keychain restore. Thrown read is [SessionRestorePhase.restoreFailed],
/// not a crash.
T? readStoredSessionSafely<T>(
  T? Function() read, {
  void Function(Object error)? onError,
}) {
  try {
    return read();
  } catch (e) {
    onError?.call(e);
    return null;
  }
}

/// Cold-start Keychain restore. Restore error wins. Missing session is
/// empty, not a hang. Expired JWT is expired, not usable.
SessionRestorePhase resolveSessionRestorePhase({
  required bool isConfigured,
  required bool isInitialized,
  required bool hasUser,
  required int? expiresAtSeconds,
  Object? restoreError,
  DateTime? now,
}) {
  if (restoreError != null) return SessionRestorePhase.restoreFailed;
  if (!isConfigured || !isInitialized) {
    return SessionRestorePhase.unconfigured;
  }
  if (!hasUser) return SessionRestorePhase.missing;
  if (isSessionExpired(expiresAtSeconds: expiresAtSeconds, now: now)) {
    return SessionRestorePhase.expired;
  }
  if (shouldAttemptSessionRefresh(
    expiresAtSeconds: expiresAtSeconds,
    now: now,
  )) {
    return SessionRestorePhase.needsRefresh;
  }
  return SessionRestorePhase.usable;
}

/// Missing / expired / Keychain fail / unconfigured → `/setup`.
/// Usable (or near-expiry) on `/setup` → `/`. Stay put otherwise.
String? sessionRestoreRedirect({
  required SessionRestorePhase phase,
  required String currentLocation,
  String signInRoute = kSessionRestoreSignInRoute,
  String homeRoute = kSessionRestoreHomeRoute,
}) {
  final onSignIn = currentLocation == signInRoute;
  final signedOut = phase == SessionRestorePhase.missing ||
      phase == SessionRestorePhase.expired ||
      phase == SessionRestorePhase.restoreFailed ||
      phase == SessionRestorePhase.unconfigured;
  if (signedOut) return onSignIn ? null : signInRoute;
  if (onSignIn) return homeRoute;
  return null;
}

bool sessionRestoreShouldAttemptRefresh(SessionRestorePhase phase) {
  return phase == SessionRestorePhase.needsRefresh ||
      phase == SessionRestorePhase.expired;
}

/// Every phase is a valid cold-start landing. Missing session is sign-in.
bool sessionRestoreAllowsColdOpen(SessionRestorePhase phase) => true;

String sessionRestoreMessage(SessionRestorePhase phase) {
  switch (phase) {
    case SessionRestorePhase.unconfigured:
      return kSessionUnconfiguredCopy;
    case SessionRestorePhase.missing:
      return kSessionMissingCopy;
    case SessionRestorePhase.expired:
      return kSessionExpiredCopy;
    case SessionRestorePhase.restoreFailed:
      return kSessionRestoreFailedCopy;
    case SessionRestorePhase.needsRefresh:
    case SessionRestorePhase.usable:
      return '';
  }
}

String? sessionRestoreHint(SessionRestorePhase phase) {
  if (phase == SessionRestorePhase.restoreFailed ||
      phase == SessionRestorePhase.expired) {
    return kSessionRestoreFailedHint;
  }
  return null;
}

Key sessionRestoreFeedbackKey(SessionRestorePhase phase) {
  switch (phase) {
    case SessionRestorePhase.unconfigured:
      return const Key('session-restore-unconfigured');
    case SessionRestorePhase.missing:
      return const Key('session-restore-missing');
    case SessionRestorePhase.expired:
      return const Key('session-restore-expired');
    case SessionRestorePhase.restoreFailed:
      return const Key('session-restore-failed');
    case SessionRestorePhase.needsRefresh:
      return const Key('session-restore-needs-refresh');
    case SessionRestorePhase.usable:
      return const Key('session-restore-usable');
  }
}

SessionRestoreResult reduceSessionRestore({
  required bool isConfigured,
  required bool isInitialized,
  required bool hasUser,
  required int? expiresAtSeconds,
  Object? restoreError,
  required String currentLocation,
  DateTime? now,
}) {
  final phase = resolveSessionRestorePhase(
    isConfigured: isConfigured,
    isInitialized: isInitialized,
    hasUser: hasUser,
    expiresAtSeconds: expiresAtSeconds,
    restoreError: restoreError,
    now: now,
  );
  return SessionRestoreResult(
    phase: phase,
    redirectTo: sessionRestoreRedirect(
      phase: phase,
      currentLocation: currentLocation,
    ),
    error: restoreError,
  );
}

/// Cold open: Keychain read may throw. Missing / expired / failed all
/// land on sign-in. Never throws.
SessionRestoreResult restoreSessionOnColdOpen({
  required bool isConfigured,
  required bool isInitialized,
  required bool Function() readHasUser,
  required int? Function() readExpiresAtSeconds,
  String currentLocation = kSessionRestoreHomeRoute,
  DateTime? now,
}) {
  Object? restoreError;
  var hasUser = false;
  int? expiresAtSeconds;
  try {
    hasUser = readHasUser();
    expiresAtSeconds = readExpiresAtSeconds();
  } catch (e) {
    restoreError = e;
  }
  return reduceSessionRestore(
    isConfigured: isConfigured,
    isInitialized: isInitialized,
    hasUser: hasUser,
    expiresAtSeconds: expiresAtSeconds,
    restoreError: restoreError,
    currentLocation: currentLocation,
    now: now,
  );
}
