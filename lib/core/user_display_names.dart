import 'package:flutter/foundation.dart';

/// `(column, value) → users row`. Test seams bind this to skip live SQL.
typedef UsersLookup = Future<Map<String, dynamic>?> Function(
  String column,
  String value,
);

const unknownUserLabel = 'Unknown User';

/// Prefer `users.id`, then `users.uid`.
Future<Map<String, dynamic>?> lookupUserByIdThenUid({
  required String key,
  required UsersLookup lookup,
}) async {
  return await lookup('id', key) ?? await lookup('uid', key);
}

bool isCurrentUserKey(String key, {String? currentUserId}) {
  return currentUserId != null &&
      currentUserId.isNotEmpty &&
      currentUserId == key;
}

/// Name from a users row. Never returns literal [unknownUserLabel] for self
/// when a row exists (null means caller must not persist that fallback).
String? displayNameFromUserRow({
  required String key,
  required Map<String, dynamic> row,
  String? currentUserId,
}) {
  final name = row['display_name'] as String?;
  if (name != null && name.isNotEmpty) return name;
  if (isCurrentUserKey(key, currentUserId: currentUserId)) return null;
  return unknownUserLabel;
}

/// Persist a looked-up display name. Skips [unknownUserLabel] for the current
/// user when a row exists under id or uid.
void persistLookedUpDisplayName({
  required Map<String, String> displayNames,
  required String key,
  required Map<String, dynamic>? row,
  String? currentUserId,
  required void Function(String fallback) onMiss,
}) {
  if (row != null) {
    final name = displayNameFromUserRow(
      key: key,
      row: row,
      currentUserId: currentUserId,
    );
    if (name != null) {
      displayNames[key] = name;
    }
    return;
  }
  if (isCurrentUserKey(key, currentUserId: currentUserId)) return;
  onMiss(unknownUserLabel);
}

/// Live users lookup: `id` then `uid`. Errors per column are logged, not thrown.
UsersLookup supabaseUsersLookup(
  Future<Map<String, dynamic>?> Function(String column, String value) query,
) {
  return (column, value) async {
    try {
      return await query(column, value);
    } catch (e) {
      debugPrint('Error looking up user by $column $value: $e');
      return null;
    }
  };
}
