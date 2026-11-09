import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/invite/data/fake_invite_repository.dart';
import 'package:squadsync/features/invite/domain/invite_code.dart';
import 'package:squadsync/features/invite/ui/invite_controller.dart';

void main() {
  test('load, rotate, and join keep the server decision', () async {
    final invites = FakeInviteRepository();
    final container = ProviderContainer(
      overrides: [inviteRepositoryProvider.overrideWithValue(invites)],
    );
    addTearDown(container.dispose);
    final board = container.read(inviteControllerProvider.notifier);

    await board.load();
    expect(container.read(inviteControllerProvider).invite, isNull);

    await board.rotate();
    expect(container.read(inviteControllerProvider).invite?.code, 'CODE2341');

    final bad = await board.join('FULL2345');
    expect(bad.error, JoinError.full);
    expect(bad.joined, isFalse);

    final good = await board.join('GOOD2345');
    expect(good.joined, isTrue);
    expect(good.squadId, 'joined');
  });

  test('a missing backend stays disabled', () async {
    final container = ProviderContainer(
      overrides: [
        inviteRepositoryProvider.overrideWithValue(
          FakeInviteRepository(notEnabled: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(inviteControllerProvider.notifier).load();
    final state = container.read(inviteControllerProvider);
    expect(state.notEnabled, isTrue);
    expect(state.invite, isNull);
  });
}
