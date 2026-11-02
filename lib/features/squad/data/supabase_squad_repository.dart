import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/core/sq8_database.dart';
import 'package:squadsync/features/squad/data/squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

class SupabaseSquadRepository implements SquadRepository {
  SupabaseSquadRepository(this._db);

  final Sq8Database _db;

  @override
  Future<Squad> load() async {
    final squadId = await _db.mySquadId();
    if (squadId == null) {
      throw const RepositoryFailure('not in a squad');
    }
    final ownerId = await _db.ownerId(squadId);
    final members = await _db.membersOf(squadId);
    return Squad(
      id: squadId,
      ownerId: ownerId,
      members: [
        for (final member in members)
          Member(
            id: member.userId,
            displayName: member.displayName,
            defaultGame: member.defaultGame,
          ),
      ],
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
