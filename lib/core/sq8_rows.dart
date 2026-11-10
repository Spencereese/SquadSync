import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/core/sq8_database.dart';

/// PostgREST `or` filter: rows strictly older than (sentAt, id).
String olderThanFilter(DateTime sentAt, String id) {
  final iso = sentAt.toUtc().toIso8601String();
  return 'sent_at.lt.$iso,and(sent_at.eq.$iso,id.lt.$id)';
}

/// Rows strictly newer than the read cursor. A null id means "after this time".
String newerThanFilter(DateTime sentAt, String? id) {
  final iso = sentAt.toUtc().toIso8601String();
  if (id == null || id.isEmpty) return 'sent_at.gt.$iso';
  return 'sent_at.gt.$iso,and(sent_at.eq.$iso,id.gt.$id)';
}

Sq8Member memberFromRow(Map<String, dynamic> row) {
  final userId = row['user_id'];
  if (userId is! String || userId.isEmpty) {
    throw const RepositoryFailure('member row is missing user_id');
  }
  final profile = _profileMap(row['sq8_profiles']);
  final name = profile?['display_name'];
  final game = profile?['default_game'];
  if (name is! String || name.trim().isEmpty) {
    throw const RepositoryFailure('profile is missing a display name');
  }
  if (game is! String || game.trim().isEmpty) {
    throw const RepositoryFailure('profile is missing a default game');
  }
  return Sq8Member(userId: userId, displayName: name, defaultGame: game);
}

Sq8Message messageFromRow(Map<String, dynamic> row) {
  final id = row['id'];
  final squadId = row['squad_id'];
  final senderId = row['sender_id'];
  final body = row['body'];
  if (id is! String || squadId is! String || senderId is! String) {
    throw const RepositoryFailure('message row is missing an id');
  }
  if (body is! String) {
    throw const RepositoryFailure('message row is missing a body');
  }
  final reply = row['reply_to_id'];
  return Sq8Message(
    id: id,
    squadId: squadId,
    senderId: senderId,
    body: body,
    sentAt: _time(row['sent_at']),
    replyToId: reply is String && reply.isNotEmpty ? reply : null,
  );
}

Sq8Cursor cursorFromRow(Map<String, dynamic> row) {
  final id = row['last_read_id'];
  return Sq8Cursor(
    lastReadAt: _time(row['last_read_at']),
    lastReadId: id is String && id.isNotEmpty ? id : null,
  );
}

Map<String, dynamic>? _profileMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return null;
}

DateTime _time(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is String && value.isNotEmpty) return DateTime.parse(value).toUtc();
  throw const RepositoryFailure('row is missing a timestamp');
}
