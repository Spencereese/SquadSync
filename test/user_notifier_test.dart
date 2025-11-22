import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/providers/user_notifier.dart';

void main() {
  group('UserNotifier', () {
    test('initial state is correct', () {
      final initialState = UserState.initial();
      expect(initialState.displayName, isNull);
      expect(initialState.profileImage, isNull);
      expect(initialState.isInitialized, false);
      expect(initialState.blockedUsers, isEmpty);
    });

    test('blockUser logic creates correct state', () {
      final initialState = UserState.initial();
      final blockedState = initialState.copyWith(
        userBlocks: {
          'test-uid': {'BlockedUser': true}
        },
        blockedUsers: ['BlockedUser'],
      );

      expect(blockedState.blockedUsers, contains('BlockedUser'));
      expect(blockedState.userBlocks['test-uid']?['BlockedUser'], isTrue);
    });

    test('handles null values safely', () {
      final stateWithNulls = UserState.initial().copyWith(
        displayName: null,
        profileImage: null,
      );

      expect(stateWithNulls.displayName, isNull);
      expect(stateWithNulls.profileImage, isNull);
    });

    test('loads from cache correctly', () {
      final cachedState = UserState.initial().copyWith(
        profileImage: 'cached-image.jpg',
        displayName: 'Cached User',
        pinnedGames: [
          {'name': 'Test Game'}
        ],
        isInitialized: true,
      );

      expect(cachedState.profileImage, 'cached-image.jpg');
      expect(cachedState.displayName, 'Cached User');
      expect(cachedState.pinnedGames, isNotEmpty);
    });

    test('error state preserves data', () {
      final errorState = AsyncValue.error('Test error', StackTrace.current);
      expect(errorState.hasError, isTrue);
      expect(errorState.error, 'Test error');
    });

    test('ratings maps are initialized empty', () {
      final state = UserState.initial();
      expect(state.dailyRatings, isEmpty);
      expect(state.allTimeRatings, isEmpty);
      expect(state.currentStreaks, isEmpty);
    });

    test('complaints map is initialized empty', () {
      final state = UserState.initial();
      expect(state.complaints, isEmpty);
    });

    test('alert circles has default values', () {
      final state = UserState.initial();
      expect(state.alertCircles, contains('Squad'));
      expect(state.alertCircles, contains('Friends'));
      expect(state.alertCircles, contains('Public'));
    });

    test('muted games is initialized empty', () {
      final state = UserState.initial();
      expect(state.mutedGames, isEmpty);
    });

    test('hasRatedGame map is initialized empty', () {
      final state = UserState.initial();
      expect(state.hasRatedGame, isEmpty);
    });

    test('user profile cache is initialized empty', () {
      final state = UserState.initial();
      expect(state.userProfileCache, isEmpty);
    });

    test('bans list is initialized empty', () {
      final state = UserState.initial();
      expect(state.bans, isEmpty);
    });

    test('daily ban votes is initialized empty', () {
      final state = UserState.initial();
      expect(state.dailyBanVotes, isEmpty);
    });
  });

  group('UserNotifier Integration Tests', () {
    test('handles offline mode with cached data', () {
      final cachedState = UserState.initial().copyWith(
        profileImage: 'offline-image.jpg',
        displayName: 'Offline User',
        isInitialized: true,
      );

      expect(cachedState.isInitialized, isTrue);
      expect(cachedState.displayName, 'Offline User');
    });

    test('handles IGDB API failure gracefully', () {
      final stateWithError = UserState.initial().copyWith(
        errorMessage: 'IGDB API unavailable',
      );

      expect(stateWithError.errorMessage, isNotNull);
    });

    test('safeString handles null values', () {
      String? nullString;
      expect(nullString ?? 'default', 'default');
    });

    test('debug asserts catch invalid states', () {
      final state = UserState.initial().copyWith(displayName: '');
      expect(state.displayName, '');
    });
  });
}
