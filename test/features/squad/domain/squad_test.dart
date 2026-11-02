import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

Member _friend(int n) {
  return Member(
    id: 'friend-$n',
    displayName: 'Friend $n',
    defaultGame: 'Battlefield',
  );
}

Squad _grow(Squad squad, Member member) {
  final result = squad.add(member);
  switch (result) {
    case AddMemberAccepted(:final squad):
      return squad;
    case AddMemberRejected(:final reason):
      fail('expected add to succeed, got $reason');
  }
}

Squad _full() {
  var squad = Squad.seed();
  for (var n = 1; n <= 7; n++) {
    squad = _grow(squad, _friend(n));
  }
  return squad;
}

void main() {
  test('Spencer owns the seed squad and defaults to Call of Duty', () {
    final squad = Squad.seed();

    expect(squad.ownerId, 'spencer');
    expect(squad.members, hasLength(1));
    expect(squad.members.single.id, spencer.id);
    expect(squad.members.single.displayName, 'Spencer');
    expect(squad.members.single.defaultGame, 'Call of Duty');
    expect(squad.chatId, squad.id);
  });

  test('a squad accepts members until it holds eight', () {
    final squad = _full();

    expect(squad.members, hasLength(squadCapacity));
    expect(squad.members.first.id, 'spencer');
    expect(squad.members.last.defaultGame, 'Battlefield');
  });

  test('adding a ninth member is rejected and the eight stay', () {
    final squad = _full();
    final before = squad.members.map((member) => member.id).toList();
    final result = squad.add(_friend(8));

    expect(result, isA<AddMemberRejected>());
    expect((result as AddMemberRejected).reason, AddRejection.full);
    expect(result.squad.members.map((member) => member.id), before);
    expect(identical(result.squad, squad), isTrue);
  });

  test('a duplicate member is rejected', () {
    final squad = Squad.seed();
    final again = squad.add(
      const Member(
        id: 'spencer',
        displayName: 'Someone else',
        defaultGame: 'Battlefield',
      ),
    );
    final copy = _grow(squad, _friend(1)).add(_friend(1));

    expect((again as AddMemberRejected).reason, AddRejection.duplicate);
    expect(again.squad.members, hasLength(1));
    expect((copy as AddMemberRejected).reason, AddRejection.duplicate);
    expect(copy.squad.members.map((member) => member.id), [
      'spencer',
      'friend-1',
    ]);
  });

  test('a blank member is rejected', () {
    final result = Squad.seed().add(
      const Member(id: 'x', displayName: 'X', defaultGame: ' '),
    );

    expect((result as AddMemberRejected).reason, AddRejection.invalid);
    expect(result.squad.members, hasLength(1));
  });

  test('a member other than the owner can be removed', () {
    final squad = _grow(Squad.seed(), _friend(1));
    final result = squad.remove('friend-1');

    expect(result, isA<RemoveMemberAccepted>());
    expect(result.squad.members.map((member) => member.id), ['spencer']);
  });

  test('the owner cannot be removed', () {
    final squad = _grow(Squad.seed(), _friend(1));
    final result = squad.remove('spencer');

    expect(result, isA<RemoveMemberRejected>());
    expect((result as RemoveMemberRejected).reason, RemoveRejection.owner);
    expect(identical(result.squad, squad), isTrue);
    expect(result.squad.members.map((member) => member.id), [
      'spencer',
      'friend-1',
    ]);
  });

  test('removing someone who is not a member changes nothing', () {
    final squad = Squad.seed();
    final result = squad.remove('missing');

    expect((result as RemoveMemberRejected).reason, RemoveRejection.missing);
    expect(identical(result.squad, squad), isTrue);
  });

  test(
    'a squad cannot be built with nine members, a duplicate, or no owner',
    () {
      final eight = _full().members;
      expect(
        () => Squad(
          id: 'squad',
          ownerId: 'spencer',
          members: [...eight, _friend(8)],
        ),
        throwsArgumentError,
      );
      expect(
        () => Squad(
          id: 'squad',
          ownerId: 'spencer',
          members: const [spencer, spencer],
        ),
        throwsArgumentError,
      );
      expect(
        () => Squad(id: 'squad', ownerId: 'spencer', members: [_friend(1)]),
        throwsArgumentError,
      );
    },
  );
}
