/// Pure session expiry checks. No Supabase imports so unit tests stay light.

bool isSessionExpired({
  required int? expiresAtSeconds,
  DateTime? now,
}) {
  if (expiresAtSeconds == null) return true;
  final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds * 1000);
  return !(now ?? DateTime.now()).isBefore(expiry);
}

/// Refresh if [expiresAtSeconds] is missing, already expired, or inside
/// [refreshWindow] of expiry.
bool shouldAttemptSessionRefresh({
  required int? expiresAtSeconds,
  DateTime? now,
  Duration refreshWindow = const Duration(minutes: 5),
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
