import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/invite/data/fake_invite_repository.dart';
import 'package:squadsync/features/invite/data/invite_repository.dart';
import 'package:squadsync/features/invite/domain/invite_code.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';

void main() {
  test(
    'each join result is distinct and a good code seats the person',
    () async {
      final squads = FakeSquadRepository(startEmpty: true);
      final invites = FakeInviteRepository(squads: squads);

      expect((await invites.join('nope')).error, JoinError.invalid);
      expect((await invites.join('EXPIRED2')).error, JoinError.expired);
      expect((await invites.join('FULL2345')).error, JoinError.full);
      expect((await invites.join('MEMBER22')).error, JoinError.alreadyInSquad);
      expect(
        (await invites.join('OWNS2345')).error,
        JoinError.ownsSquadWithMembers,
      );
      expect(squads.findMine(), completion(isNull));

      final joined = await invites.join('good-2345');
      expect(joined.joined, isTrue);
      expect((await squads.findMine())?.id, 'joined');
    },
  );

  test('rotating replaces the code', () async {
    final invites = FakeInviteRepository();
    final first = await invites.createOrRotate();
    final second = await invites.createOrRotate();
    expect(second.code, isNot(first.code));
    expect(await invites.current(), second);
  });

  test('a missing invite backend is not a code', () async {
    final invites = FakeInviteRepository(notEnabled: true);
    expect(invites.current(), throwsA(isA<InvitesNotEnabled>()));
    expect((await invites.join('GOOD2345')).notEnabled, isTrue);
  });
}
