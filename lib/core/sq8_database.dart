/// What a realtime roster channel reported.
///
/// [deleted] is a member row going away. Row level security can hide that
/// delete from the person who was removed, so callers also re-check
/// membership when no event arrives.
enum RosterSignal { changed, deleted }

/// Rows the squad and chat repositories need. The Supabase adapter and the
/// test double both speak this. Widgets do not.
class Sq8Member {
  const Sq8Member({
    required this.userId,
    required this.displayName,
    required this.defaultGame,
  });

  final String userId;
  final String displayName;
  final String defaultGame;
}

class Sq8Message {
  const Sq8Message({
    required this.id,
    required this.squadId,
    required this.senderId,
    required this.body,
    required this.sentAt,
    this.replyToId,
  });

  final String id;
  final String squadId;
  final String senderId;
  final String body;
  final DateTime sentAt;
  final String? replyToId;
}

class Sq8Cursor {
  const Sq8Cursor({required this.lastReadAt, this.lastReadId});

  final DateTime lastReadAt;
  final String? lastReadId;
}

class Sq8DuplicateRow implements Exception {
  const Sq8DuplicateRow();
}

class Sq8SquadFull implements Exception {
  const Sq8SquadFull();
}

class Sq8OwnerProtected implements Exception {
  const Sq8OwnerProtected();
}

abstract class Sq8Database {
  String? get userId;

  Future<Sq8Member?> myProfile();

  Future<void> updateMyProfile({
    required String displayName,
    required String defaultGame,
  });

  /// Inserts the signed-in person's profile only. Does not update an existing row.
  Future<void> insertMyProfile({
    required String displayName,
    required String defaultGame,
  });

  Future<String?> mySquadId();

  /// Inserts a squad owned by the signed-in person. The database seats them.
  Future<String> createSquad();

  /// Member and, when [squadId] is set, message inserts for that squad.
  /// [RosterSignal.deleted] is a member-row delete. The stream is empty when
  /// realtime is not available. A missing delete is not proof of membership.
  Stream<RosterSignal> watchRoster({String? squadId, required String userId});

  Future<String> ownerId(String squadId);

  Future<List<Sq8Member>> membersOf(String squadId);

  Future<void> insertMember({required String squadId, required String userId});

  /// True when a row was actually deleted. False when the delete matched nothing.
  Future<bool> deleteMember({required String squadId, required String userId});

  /// Newest first.
  Future<List<Sq8Message>> newestMessages(String squadId, {required int limit});

  /// Newest first, strictly before [before] / [beforeId].
  Future<List<Sq8Message>> olderMessages(
    String squadId, {
    required DateTime before,
    required String beforeId,
    required int limit,
  });

  Future<void> insertMessage(Sq8Message message);

  /// Bodies for these ids. An id that is gone is omitted.
  Future<Map<String, String>> messageBodies(Iterable<String> ids);

  Stream<Sq8Message> watchInserts(String squadId);

  Future<Sq8Cursor?> readCursor(String squadId);

  Future<int> unreadCount(String squadId, Sq8Cursor? cursor);

  Future<void> upsertCursor({
    required String squadId,
    required DateTime lastReadAt,
    String? lastReadId,
  });
}
