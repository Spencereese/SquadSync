import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/data/fake_availability_repository.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/availability/ui/availability_controller.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

const _friend = Member(
  id: 'friend',
  displayName: 'Friend',
  defaultGame: 'Call of Duty',
);

Squad _squad() {
  return Squad(
    id: 'squad',
    ownerId: spencer.id,
    members: const [spencer, _friend],
  );
}

void main() {
  test('a failed save writes nothing and retry writes once', () async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final repo = FakeAvailabilityRepository(clock: clock, failSave: true);
    final container = ProviderContainer(
      overrides: [
        squadClockProvider.overrideWithValue(clock),
        availabilityRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final board = container.read(availabilityControllerProvider.notifier);
    await board.open(squad: _squad(), meId: 'spencer');

    await board.save(const CheckInDraft.now());

    expect(repo.rows, isEmpty);
    expect(
      container.read(availabilityControllerProvider).error,
      'Could not save your check-in. Nothing was saved.',
    );
    expect(
      container.read(availabilityControllerProvider).board!.availableNowCount,
      0,
    );

    repo.failSave = false;
    await board.retry();

    expect(repo.rows, hasLength(1));
    expect(repo.rows.single.userId, 'spencer');
    expect(repo.rows.single.kind, CheckInKind.availableNow);
    expect(repo.rows.single.until, DateTime.utc(2026, 11, 8, 16));
    expect(
      container.read(availabilityControllerProvider).board!.availableNowCount,
      1,
    );
    expect(container.read(availabilityControllerProvider).pending, isNull);
  });

  test(
    'a failed refresh keeps the last rows and still lets them expire',
    () async {
      final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
      final repo = FakeAvailabilityRepository(
        clock: clock,
        seed: [
          StoredCheckIn(
            userId: 'spencer',
            squadId: 'squad',
            kind: CheckInKind.availableNow,
            checkedAt: clock.now(),
            until: clock.now().add(availableNowWindow),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          squadClockProvider.overrideWithValue(clock),
          availabilityRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final board = container.read(availabilityControllerProvider.notifier);
      await board.open(squad: _squad(), meId: 'spencer');
      expect(
        container.read(availabilityControllerProvider).board!.availableNowCount,
        1,
      );

      repo.failLoad = true;
      await board.refresh();
      final stale = container.read(availabilityControllerProvider);
      expect(stale.stale, isTrue);
      expect(stale.board!.availableNowCount, 1);
      expect(stale.error, 'Could not load check-ins.');

      clock.advance(availableNowWindow);
      board.reevaluate();
      final expired = container.read(availabilityControllerProvider);
      expect(expired.stale, isTrue);
      expect(expired.board!.availableNowCount, 0);
      expect(
        expired.board!.person('spencer')!.effect,
        AvailabilityEffect.expired,
      );
    },
  );

  test(
    'an account change does not keep or overwrite the previous check-in',
    () async {
      final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
      final repo = FakeAvailabilityRepository(clock: clock);
      final container = ProviderContainer(
        overrides: [
          squadClockProvider.overrideWithValue(clock),
          availabilityRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final board = container.read(availabilityControllerProvider.notifier);
      await board.open(squad: _squad(), meId: 'spencer');
      await board.save(const CheckInDraft.now());

      repo.userId = 'friend';
      await board.open(squad: _squad(), meId: 'friend');

      final state = container.read(availabilityControllerProvider);
      expect(state.meId, 'friend');
      expect(
        state.board!.person('friend')!.effect,
        AvailabilityEffect.notCheckedIn,
      );
      expect(
        state.board!.person('spencer')!.effect,
        AvailabilityEffect.availableNow,
      );

      await board.save(const CheckInDraft.unavailable());

      expect(repo.rows, hasLength(2));
      final spencerRow = repo.rows.singleWhere(
        (row) => row.userId == 'spencer',
      );
      final friendRow = repo.rows.singleWhere((row) => row.userId == 'friend');
      expect(spencerRow.kind, CheckInKind.availableNow);
      expect(friendRow.kind, CheckInKind.unavailable);
      final after = container.read(availabilityControllerProvider);
      expect(
        after.board!.person('spencer')!.effect,
        AvailabilityEffect.availableNow,
      );
      expect(
        after.board!.person('friend')!.effect,
        AvailabilityEffect.unavailable,
      );
    },
  );

  test('clear removes only the signed-in row', () async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final repo = FakeAvailabilityRepository(
      clock: clock,
      seed: [
        StoredCheckIn(
          userId: 'friend',
          squadId: 'squad',
          kind: CheckInKind.unavailable,
          checkedAt: clock.now(),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        squadClockProvider.overrideWithValue(clock),
        availabilityRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final board = container.read(availabilityControllerProvider.notifier);
    await board.open(squad: _squad(), meId: 'spencer');
    await board.save(const CheckInDraft.now());
    await board.clear();

    expect(repo.rows.map((row) => row.userId), ['friend']);
    expect(
      container
          .read(availabilityControllerProvider)
          .board!
          .person('spencer')!
          .effect,
      AvailabilityEffect.notCheckedIn,
    );
  });

  test('a missing table is not an empty successful board', () async {
    final repo = FakeAvailabilityRepository(
      clock: ManualSquadClock(DateTime.utc(2026, 11, 8, 15)),
      notEnabled: true,
    );
    final container = ProviderContainer(
      overrides: [availabilityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container
        .read(availabilityControllerProvider.notifier)
        .open(squad: _squad(), meId: 'spencer');
    final state = container.read(availabilityControllerProvider);
    expect(state.notEnabled, isTrue);
    expect(state.board, isNull);
    expect(repo.rows, isEmpty);
  });
}
