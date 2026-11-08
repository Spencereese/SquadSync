import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/core/sq8_database.dart';
import 'package:squadsync/features/squad/data/squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

class SupabaseSquadRepository implements SquadRepository {
  SupabaseSquadRepository(this._db);

  final Sq8Database _db;

  @override
  Future<Member?> myProfile() async {
    final row = await _db.myProfile();
    if (row == null) return null;
    return _member(row);
  }

  @override
  Future<Member> ensureMyProfile({
    required String displayName,
    required String defaultGame,
  }) async {
    final existing = await myProfile();
    if (existing != null) return existing;
    final next = Member(
      id: _db.userId ?? '',
      displayName: displayName.trim(),
      defaultGame: defaultGame.trim(),
    );
    if (!next.isValid) {
      throw const RepositoryFailure('profile is incomplete');
    }
    try {
      await _db.insertMyProfile(
        displayName: next.displayName,
        defaultGame: next.defaultGame,
      );
    } on Sq8DuplicateRow {
      final raced = await myProfile();
      if (raced != null) return raced;
      rethrow;
    }
    final created = await myProfile();
    if (created == null) {
      throw const RepositoryFailure(
        'The server cannot create your profile yet. Nothing was saved.',
      );
    }
    return created;
  }

  @override
  Future<Member> saveProfile({
    required String displayName,
    required String defaultGame,
  }) async {
    final next = Member(
      id: _db.userId ?? '',
      displayName: displayName.trim(),
      defaultGame: defaultGame.trim(),
    );
    if (!next.isValid) {
      throw const RepositoryFailure('profile is incomplete');
    }
    await _db.updateMyProfile(
      displayName: next.displayName,
      defaultGame: next.defaultGame,
    );
    return next;
  }

  @override
  Future<Squad?> findMine() async {
    final squadId = await _db.mySquadId();
    if (squadId == null) return null;
    return _squad(squadId);
  }

  @override
  Future<Squad> createMine() async {
    final existing = await findMine();
    if (existing != null) return existing;
    try {
      final squadId = await _db.createSquad();
      return await _squad(squadId);
    } on Sq8DuplicateRow {
      final raced = await findMine();
      if (raced != null) return raced;
      rethrow;
    }
  }

  @override
  Future<Squad> load() async {
    final squad = await findMine();
    if (squad == null) {
      throw const RepositoryFailure('not in a squad');
    }
    return squad;
  }

  Future<Squad> _squad(String squadId) async {
    final ownerId = await _db.ownerId(squadId);
    final members = await _db.membersOf(squadId);
    return Squad(
      id: squadId,
      ownerId: ownerId,
      members: [for (final member in members) _member(member)],
    );
  }

  Member _member(Sq8Member member) {
    return Member(
      id: member.userId,
      displayName: member.displayName,
      defaultGame: member.defaultGame,
    );
  }

  @override
  Future<AddMember> addMember(Member member) async {
    final current = await load();
    final decided = current.add(member);
    if (decided is! AddMemberAccepted) return decided;
    try {
      await _db.insertMember(squadId: current.id, userId: member.id);
    } on Sq8DuplicateRow {
      return AddMemberRejected(current, AddRejection.duplicate);
    } on Sq8SquadFull {
      return AddMemberRejected(current, AddRejection.full);
    }
    return decided;
  }

  @override
  Future<RemoveMember> removeMember(String memberId) async {
    final current = await load();
    final decided = current.remove(memberId);
    if (decided is! RemoveMemberAccepted) return decided;
    try {
      await _db.deleteMember(squadId: current.id, userId: memberId);
    } on Sq8OwnerProtected {
      return RemoveMemberRejected(current, RemoveRejection.owner);
    }
    return decided;
  }
}
