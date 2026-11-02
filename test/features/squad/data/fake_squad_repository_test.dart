import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

void main() {
  test('load returns the Spencer seed', () async {
    final repo = FakeSquadRepository();
    final squad = await repo.load();

    expect(squad.ownerId, 'spencer');
    expect(squad.members.single.defaultGame, 'Call of Duty');
  });

  test('the failure toggle throws and does not change the squad', () async {
    final repo = FakeSquadRepository(fail: true);
    final before = repo.snapshot.members.map((member) => member.id).toList();

    expect(repo.load(), throwsA(isA<RepositoryFailure>()));
    expect(
      repo.addMember(
        const Member(id: 'friend', displayName: 'Friend', defaultGame: 'Halo'),
      ),
      throwsA(isA<RepositoryFailure>()),
    );
    expect(repo.removeMember('spencer'), throwsA(isA<RepositoryFailure>()));
    expect(repo.snapshot.members.map((member) => member.id), before);

    repo.fail = false;
    final added = await repo.addMember(
      const Member(id: 'friend', displayName: 'Friend', defaultGame: 'Halo'),
    );
    expect(added, isA<AddMemberAccepted>());
    expect(repo.snapshot.members, hasLength(2));
  });

  test('a ninth member is rejected and the owner stays', () async {
    final repo = FakeSquadRepository();
    for (var n = 1; n <= 7; n++) {
      final result = await repo.addMember(
        Member(
          id: 'friend-$n',
          displayName: 'Friend $n',
          defaultGame: 'Battlefield',
        ),
      );
      expect(result, isA<AddMemberAccepted>());
    }

    final ninth = await repo.addMember(
      const Member(
        id: 'friend-8',
        displayName: 'Friend 8',
        defaultGame: 'Halo',
      ),
    );
    final removed = await repo.removeMember('spencer');

    expect((ninth as AddMemberRejected).reason, AddRejection.full);
    expect(repo.snapshot.members, hasLength(8));
    expect((removed as RemoveMemberRejected).reason, RemoveRejection.owner);
    expect(repo.snapshot.members.first.id, 'spencer');
  });
}
