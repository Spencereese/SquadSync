import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/services/constitution_manager.dart';

void main() {
  test('no-arg ConstitutionManager fails clearly without a client', () {
    expect(
      () => ConstitutionManager(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('injected SupabaseClient'),
        ),
      ),
    );
  });

  test('supabaseClientProvider fails clearly when uninitialized', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(supabaseClientProvider),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not initialized'),
        ),
      ),
    );
  });

  test('constitutionManagerProvider default does not hit Supabase.instance',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(constitutionManagerProvider),
      throwsA(isA<StateError>()),
    );
  });

  test('constitutionManagerProvider override skips live client', () {
    final container = ProviderContainer(
      overrides: [
        constitutionManagerProvider.overrideWithValue(
          _FakeConstitutionManager(),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(constitutionManagerProvider),
      isA<_FakeConstitutionManager>(),
    );
  });

  group('voteUpdatePayload', () {
    test('first yes vote counts 1/0', () {
      expect(
        ConstitutionManager.voteUpdatePayload(
          existingVotes: const {},
          userId: 'u1',
          yes: true,
        ),
        {
          'votes': {'u1': true},
          'vote_count_yes': 1,
          'vote_count_no': 0,
        },
      );
    });

    test('no vote increments no count', () {
      expect(
        ConstitutionManager.voteUpdatePayload(
          existingVotes: const {'u1': true},
          userId: 'u2',
          yes: false,
        ),
        {
          'votes': {'u1': true, 'u2': false},
          'vote_count_yes': 1,
          'vote_count_no': 1,
        },
      );
    });

    test('same user flipping yes to no retallies', () {
      expect(
        ConstitutionManager.voteUpdatePayload(
          existingVotes: const {'u1': true, 'u2': true},
          userId: 'u1',
          yes: false,
        ),
        {
          'votes': {'u1': false, 'u2': true},
          'vote_count_yes': 1,
          'vote_count_no': 1,
        },
      );
    });
  });
}

class _FakeConstitutionManager extends Fake implements ConstitutionManager {}
