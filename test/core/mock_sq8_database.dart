import 'dart:async';

import 'package:squadsync/core/sq8_database.dart';

class MockSq8Database implements Sq8Database {
  MockSq8Database({this.userId = 'user-1'});

  @override
  String? userId;

  String? squadId = 'squad';
  String owner = 'user-1';
  List<Sq8Member> members = const [];

  /// Newest first.
  List<Sq8Message> messages = const [];

  int unread = 0;
  Sq8Cursor? cursor;
  Sq8Member? profile = const Sq8Member(
    userId: 'user-1',
    displayName: 'Spencer',
    defaultGame: 'Call of Duty',
  );
  var createCalls = 0;
  var profileInserts = 0;
  var duplicateOwner = false;
  var duplicateProfile = false;
  var duplicate = false;
  Object? insertMemberError;
  Object? deleteMemberError;
  var cursorWrites = 0;
  int? lastNewestLimit;
  DateTime? lastOlderBefore;
  String? lastOlderBeforeId;
  Sq8Cursor? lastUnreadCursor;

  final insertedMembers = <String>[];
  final deletedMembers = <String>[];
  final insertedMessages = <Sq8Message>[];
  final _inserts = StreamController<Sq8Message>.broadcast();

  void emit(Sq8Message message) => _inserts.add(message);

  @override
  Future<Sq8Member?> myProfile() async => profile;

  @override
  Future<void> updateMyProfile({
    required String displayName,
    required String defaultGame,
  }) async {
    final current = profile;
    profile = Sq8Member(
      userId: current?.userId ?? userId ?? '',
      displayName: displayName,
      defaultGame: defaultGame,
    );
  }

  @override
  Future<void> insertMyProfile({
    required String displayName,
    required String defaultGame,
  }) async {
    profileInserts += 1;
    if (duplicateProfile) {
      profile = const Sq8Member(
        userId: 'user-1',
        displayName: 'Spencer',
        defaultGame: 'Call of Duty',
      );
      throw const Sq8DuplicateRow();
    }
    profile = Sq8Member(
      userId: userId ?? 'user-1',
      displayName: displayName,
      defaultGame: defaultGame,
    );
  }

  @override
  Future<String> createSquad() async {
    createCalls += 1;
    if (duplicateOwner) {
      squadId = 'kept-squad';
      owner = userId ?? owner;
      members = [
        profile ??
            Sq8Member(
              userId: owner,
              displayName: 'Spencer',
              defaultGame: 'Call of Duty',
            ),
      ];
      throw const Sq8DuplicateRow();
    }
    final id = squadId ?? 'new-squad';
    squadId = id;
    final me = userId ?? owner;
    owner = me;
    members = [
      profile ??
          Sq8Member(
            userId: me,
            displayName: 'Spencer',
            defaultGame: 'Call of Duty',
          ),
    ];
    return id;
  }

  @override
  Future<String?> mySquadId() async => squadId;

  @override
  Future<String> ownerId(String squadId) async => owner;

  @override
  Future<List<Sq8Member>> membersOf(String squadId) async => members;

  @override
  Future<void> insertMember({
    required String squadId,
    required String userId,
  }) async {
    final error = insertMemberError;
    if (error != null) throw error;
    insertedMembers.add(userId);
  }

  @override
  Future<void> deleteMember({
    required String squadId,
    required String userId,
  }) async {
    final error = deleteMemberError;
    if (error != null) throw error;
    deletedMembers.add(userId);
  }

  @override
  Future<List<Sq8Message>> newestMessages(
    String squadId, {
    required int limit,
  }) async {
    lastNewestLimit = limit;
    return messages.take(limit).toList();
  }

  @override
  Future<List<Sq8Message>> olderMessages(
    String squadId, {
    required DateTime before,
    required String beforeId,
    required int limit,
  }) async {
    lastOlderBefore = before;
    lastOlderBeforeId = beforeId;
    return messages.take(limit).toList();
  }

  Object? insertError;

  @override
  Future<void> insertMessage(Sq8Message message) async {
    final error = insertError;
    if (error != null) throw error;
    if (duplicate) throw const Sq8DuplicateRow();
    insertedMessages.add(message);
  }

  @override
  Stream<Sq8Message> watchInserts(String squadId) => _inserts.stream;

  @override
  Future<Sq8Cursor?> readCursor(String squadId) async => cursor;

  @override
  Future<int> unreadCount(String squadId, Sq8Cursor? cursor) async {
    lastUnreadCursor = cursor;
    return unread;
  }

  @override
  Future<void> upsertCursor({
    required String squadId,
    required DateTime lastReadAt,
    String? lastReadId,
  }) async {
    cursorWrites += 1;
    cursor = Sq8Cursor(lastReadAt: lastReadAt, lastReadId: lastReadId);
  }
}
