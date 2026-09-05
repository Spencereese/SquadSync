import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/domain/entities/constitution.dart';
import 'package:squad_sync/services/constitution_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  group('injected SupabaseClient', () {
    test('constructs against a fake client without Supabase.instance', () {
      final manager = ConstitutionManager(supabase: _FakeSupabaseClient());
      expect(manager.currentUserId, isNull);
    });

    test('currentUserId reads the injected auth user', () {
      final manager = ConstitutionManager(
        supabase: _FakeSupabaseClient(userId: 'u1'),
      );
      expect(manager.currentUserId, 'u1');
    });

    test('submitVote throws when the injected client has no session', () {
      final manager = ConstitutionManager(supabase: _FakeSupabaseClient());
      expect(
        manager.submitVote(vote: _sampleVote(), yes: true),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('no authenticated user'),
          ),
        ),
      );
    });

    test('constitutionManagerProvider injects overridden supabaseClientProvider',
        () {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(
            _FakeSupabaseClient(userId: 'u9'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final manager = container.read(constitutionManagerProvider);
      expect(manager, isA<ConstitutionManager>());
      expect(manager, isNot(isA<_FakeConstitutionManager>()));
      expect(manager.currentUserId, 'u9');
    });

    test('requiresCheckIn and getCheckInInterval use injected client', () {
      final manager = ConstitutionManager(supabase: _FakeSupabaseClient());
      expect(manager.requiresCheckIn({'check_in_required': true}), isTrue);
      expect(manager.requiresCheckIn({'check_in_required': false}), isFalse);
      expect(manager.requiresCheckIn(const {}), isFalse);
      expect(
        manager.getCheckInInterval({'check_in_interval': '15m'}),
        const Duration(minutes: 15),
      );
      expect(
        manager.getCheckInInterval({'check_in_interval': '2h'}),
        const Duration(hours: 2),
      );
      expect(
        manager.getCheckInInterval({'check_in_interval': '30s'}),
        const Duration(seconds: 30),
      );
      expect(manager.getCheckInInterval(const {}), isNull);
      expect(
        manager.getCheckInInterval({'check_in_interval': 'nope'}),
        isNull,
      );
    });
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

ConstitutionVote _sampleVote() {
  return ConstitutionVote(
    id: 'vote-1',
    constitutionId: 'c1',
    chatGroupId: 'g1',
    proposedRules: const {'mic_required': true},
    proposedBy: 'u2',
    expiresAt: DateTime.utc(2026, 9, 6),
    createdAt: DateTime.utc(2026, 9, 5),
  );
}

class _FakeConstitutionManager extends Fake implements ConstitutionManager {}

class _FakeUser extends Fake implements User {
  _FakeUser(this.id);

  @override
  final String id;
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  _FakeGoTrueClient({String? userId})
      : currentUser = userId == null ? null : _FakeUser(userId);

  @override
  final User? currentUser;
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient({String? userId})
      : auth = _FakeGoTrueClient(userId: userId);

  @override
  final GoTrueClient auth;
}
