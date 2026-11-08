import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/core/sq8_database.dart';
import 'package:squadsync/features/squad/data/supabase_squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

import '../../../core/mock_sq8_database.dart';

Sq8Member _member(String id, {String game = 'Battlefield'}) {
  return Sq8Member(userId: id, displayName: id, defaultGame: game);
}

void main() {
  test('load maps the owner and each member profile', () async {
    final db = MockSq8Database()
      ..owner = 'spencer'
      ..members = [_member('spencer', game: 'Call of Duty'), _member('friend')];
    final repo = SupabaseSquadRepository(db);

    final squad = await repo.load();

    expect(squad.ownerId, 'spencer');
    expect(squad.members.map((member) => member.defaultGame), [
      'Call of Duty',
      'Battlefield',
    ]);
  });

  test('ensure keeps an existing profile instead of writing over it', () async {
    final db = MockSq8Database();
    final repo = SupabaseSquadRepository(db);

    final kept = await repo.ensureMyProfile(
      displayName: 'Nope',
      defaultGame: 'Halo',
    );

    expect(kept.displayName, 'Spencer');
    expect(kept.defaultGame, 'Call of Duty');
    expect(db.profileInserts, 0);
  });

  test('a duplicate profile insert keeps the server fields', () async {
    final db = MockSq8Database()
      ..profile = null
      ..duplicateProfile = true;
    final repo = SupabaseSquadRepository(db);

    final kept = await repo.ensureMyProfile(
      displayName: 'Nope',
      defaultGame: 'Halo',
    );

    expect(kept.displayName, 'Spencer');
    expect(kept.defaultGame, 'Call of Duty');
  });

  test('a lost create race returns the squad that won', () async {
    final db = MockSq8Database()
      ..squadId = null
      ..duplicateOwner = true;
    final repo = SupabaseSquadRepository(db);

    final squad = await repo.createMine();

    expect(squad.id, 'kept-squad');
    expect(squad.members, hasLength(1));
    expect(db.createCalls, 1);
  });

  test(
    'createMine seats the owner once and does not open a second squad',
    () async {
      final db = MockSq8Database()..squadId = null;
      final repo = SupabaseSquadRepository(db);

      final created = await repo.createMine();
      final again = await repo.createMine();

      expect(db.createCalls, 1);
      expect(created.members, hasLength(1));
      expect(created.ownerId, 'user-1');
      expect(created.members.single.defaultGame, 'Call of Duty');
      expect(again.id, created.id);
    },
  );

  test('a missing squad is a repository failure', () async {
    final repo = SupabaseSquadRepository(MockSq8Database()..squadId = null);

    expect(repo.load(), throwsA(isA<RepositoryFailure>()));
  });

  test('the ninth member is rejected before an insert', () async {
    final db = MockSq8Database()
      ..owner = 'spencer'
      ..members = [
        _member('spencer'),
        for (var n = 1; n <= 7; n++) _member('friend-$n'),
      ];
    final repo = SupabaseSquadRepository(db);

    final result = await repo.addMember(
      const Member(id: 'ninth', displayName: 'Nine', defaultGame: 'Halo'),
    );

    expect((result as AddMemberRejected).reason, AddRejection.full);
    expect(db.insertedMembers, isEmpty);
  });

  test('a server cap error is a full squad', () async {
    final db = MockSq8Database()
      ..owner = 'spencer'
      ..members = [_member('spencer')]
      ..insertMemberError = const Sq8SquadFull();
    final repo = SupabaseSquadRepository(db);

    final result = await repo.addMember(
      const Member(id: 'friend', displayName: 'Friend', defaultGame: 'Halo'),
    );

    expect((result as AddMemberRejected).reason, AddRejection.full);
  });

  test('the server refusing to drop the owner stays a rejection', () async {
    final db = MockSq8Database()
      ..owner = 'spencer'
      ..members = [_member('spencer'), _member('friend')]
      ..deleteMemberError = const Sq8OwnerProtected();
    final repo = SupabaseSquadRepository(db);

    final result = await repo.removeMember('friend');

    expect((result as RemoveMemberRejected).reason, RemoveRejection.owner);
    expect(db.deletedMembers, isEmpty);
  });
}
