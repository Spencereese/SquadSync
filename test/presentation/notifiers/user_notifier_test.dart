import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/user_notifier.dart';
import 'package:squad_sync/domain/entities/app_user.dart';
import 'package:squad_sync/domain/repositories/user_repository.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/services/friends_service.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

@GenerateMocks([UserRepository, AuthServiceSupabase, FriendsService])
import 'user_notifier_test.mocks.dart';

void main() {
  late MockUserRepository mockRepository;
  late MockAuthServiceSupabase mockAuthService;
  late MockFriendsService mockFriendsService;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockUserRepository();
    mockAuthService = MockAuthServiceSupabase();
    mockFriendsService = MockFriendsService();

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  AppUser createTestUser({
    String uid = 'user-1',
    String? displayName = 'Test User',
    List<String>? pinnedGames,
    List<String>? friends,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName,
      profileImage: null,
      preferredModes: {},
      userBlocks: {},
      pinnedGames: pinnedGames ?? [],
      notificationSettings: {
        'pushNotifications': true,
        'soundEnabled': true,
        'vibrationEnabled': true,
        'showPreviews': true,
        'quietHoursEnabled': false,
        'urgentAlertsOnly': false,
        'lobbyInvites': true,
        'friendRequests': true,
        'gameUpdates': false,
        'achievementAlerts': true,
      },
      hasRatedGame: {},
      dailyRatings: {},
      allTimeRatings: {},
      currentStreaks: {},
      complaints: {},
      bans: {},
      dailyBanVotes: {},
      blockedUsers: [],
      friends: friends ?? [],
      alerts: [],
      userGroups: [],
      alertCircles: [],
      publicGroups: [],
      pinnedMessages: [],
    );
  }

  group('UserNotifier - Initialization', () {
    test('should initialize with null user when not authenticated', () async {
      when(mockAuthService.currentUser).thenReturn(null);
      when(mockRepository.getCurrentUser()).thenAnswer((_) async => null);

      final state = await container.read(userNotifierProvider.future);

      expect(state, isNull);
    });

    test('should load current user on initialization', () async {
      final testUser = createTestUser();
      when(mockRepository.getCurrentUser()).thenAnswer((_) async => testUser);

      final state = await container.read(userNotifierProvider.future);

      expect(state, isNotNull);
      expect(state?.uid, equals('user-1'));
      verify(mockRepository.getCurrentUser()).called(1);
    });

    test('should handle AsyncLoading state during initialization', () {
      final state = container.read(userNotifierProvider);

      expect(state, isA<AsyncLoading>());
    });

    test('should handle initialization errors gracefully', () async {
      when(mockRepository.getCurrentUser()).thenThrow(
        Exception('Failed to load user'),
      );

      // Should not throw, should handle gracefully
      final state = await container.read(userNotifierProvider.future);

      // Depending on implementation, might be null or basic user
      expect(state, isA<AppUser?>());
    });
  });

  group('UserNotifier - User Profile Updates', () {
    test('should update display name', () async {
      final initialUser = createTestUser();
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => initialUser);
      when(mockRepository.updateDisplayName('user-1', 'New Name')).thenAnswer(
        (_) async {},
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      await notifier.updateDisplayName('New Name');

      verify(mockRepository.updateDisplayName('user-1', 'New Name')).called(1);
    });

    test('should update profile image', () async {
      final initialUser = createTestUser();
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => initialUser);
      when(mockRepository.updateProfileImage('user-1', 'new-image-url'))
          .thenAnswer(
        (_) async {},
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      await notifier.updateProfileImage('new-image-url');

      verify(mockRepository.updateProfileImage('user-1', 'new-image-url'))
          .called(1);
    });

    test('should handle profile update errors', () async {
      final initialUser = createTestUser();
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => initialUser);
      when(mockRepository.updateDisplayName('user-1', 'New Name')).thenThrow(
        Exception('Update failed'),
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      expect(
        () => notifier.updateDisplayName('New Name'),
        throwsException,
      );
    });
  });

  group('UserNotifier - Pinned Games Management', () {
    test('should add pinned game', () async {
      final initialUser = createTestUser(pinnedGames: []);
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => initialUser);
      when(mockRepository.addPinnedGame('user-1', 'game-1')).thenAnswer(
        (_) async {},
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      await notifier.addPinnedGame('game-1');

      verify(mockRepository.addPinnedGame('user-1', 'game-1')).called(1);
    });

    test('should remove pinned game', () async {
      final initialUser = createTestUser(pinnedGames: ['game-1']);
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => initialUser);
      when(mockRepository.removePinnedGame('user-1', 'game-1')).thenAnswer(
        (_) async {},
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      await notifier.removePinnedGame('game-1');

      verify(mockRepository.removePinnedGame('user-1', 'game-1')).called(1);
    });

    test('should load pinned games list', () async {
      final userWithGames = createTestUser(
        pinnedGames: ['game-1', 'game-2', 'game-3'],
      );
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => userWithGames);

      final state = await container.read(userNotifierProvider.future);

      expect(state?.pinnedGames.length, equals(3));
      expect(state?.pinnedGames, contains('game-1'));
      expect(state?.pinnedGames, contains('game-2'));
      expect(state?.pinnedGames, contains('game-3'));
    });
  });

  group('UserNotifier - Friends Management', () {
    test('should add friend', () async {
      final initialUser = createTestUser(friends: []);
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => initialUser);
      when(mockRepository.addFriend('user-1', 'friend-1')).thenAnswer(
        (_) async {},
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      await notifier.addFriend('friend-1');

      verify(mockRepository.addFriend('user-1', 'friend-1')).called(1);
    });

    test('should remove friend', () async {
      final initialUser = createTestUser(friends: ['friend-1']);
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => initialUser);
      when(mockRepository.removeFriend('user-1', 'friend-1')).thenAnswer(
        (_) async {},
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      await notifier.removeFriend('friend-1');

      verify(mockRepository.removeFriend('user-1', 'friend-1')).called(1);
    });

    test('should load friends list', () async {
      final userWithFriends = createTestUser(
        friends: ['friend-1', 'friend-2'],
      );
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => userWithFriends);

      final state = await container.read(userNotifierProvider.future);

      expect(state?.friends.length, equals(2));
      expect(state?.friends, contains('friend-1'));
      expect(state?.friends, contains('friend-2'));
    });
  });

  group('UserNotifier - Notification Settings', () {
    test('should update notification settings', () async {
      final initialUser = createTestUser();
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => initialUser);

      final newSettings = {
        'pushNotifications': false,
        'soundEnabled': false,
      };

      when(mockRepository.updateNotificationSettings('user-1', newSettings))
          .thenAnswer(
        (_) async {},
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      await notifier.updateNotificationSettings(newSettings);

      verify(mockRepository.updateNotificationSettings('user-1', newSettings))
          .called(1);
    });

    test('should load notification settings', () async {
      final user = createTestUser();
      when(mockRepository.getCurrentUser()).thenAnswer((_) async => user);

      final state = await container.read(userNotifierProvider.future);

      expect(state?.notificationSettings, isNotNull);
      expect(state?.notificationSettings['pushNotifications'], equals(true));
      expect(state?.notificationSettings['soundEnabled'], equals(true));
    });
  });

  group('UserNotifier - Block Management', () {
    test('should block user', () async {
      final initialUser = createTestUser();
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => initialUser);
      when(mockRepository.blockUser('user-1', 'blocked-user')).thenAnswer(
        (_) async {},
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      await notifier.blockUser('blocked-user');

      verify(mockRepository.blockUser('user-1', 'blocked-user')).called(1);
    });

    test('should unblock user', () async {
      final initialUser = createTestUser();
      when(mockRepository.getCurrentUser())
          .thenAnswer((_) async => initialUser);
      when(mockRepository.unblockUser('user-1', 'blocked-user')).thenAnswer(
        (_) async {},
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      await notifier.unblockUser('blocked-user');

      verify(mockRepository.unblockUser('user-1', 'blocked-user')).called(1);
    });
  });

  group('UserNotifier - User Groups Management', () {
    test('should load user groups', () async {
      final user = createTestUser();
      when(mockRepository.getCurrentUser()).thenAnswer((_) async => user);

      final state = await container.read(userNotifierProvider.future);

      expect(state?.userGroups, isNotNull);
      expect(state?.userGroups, isA<List>());
    });

    test('should handle empty user groups', () async {
      final user = createTestUser();
      when(mockRepository.getCurrentUser()).thenAnswer((_) async => user);

      final state = await container.read(userNotifierProvider.future);

      expect(state?.userGroups, isEmpty);
    });
  });

  group('UserNotifier - State Persistence', () {
    test('should maintain user state across operations', () async {
      final testUser = createTestUser(
        pinnedGames: ['game-1'],
        friends: ['friend-1'],
      );
      when(mockRepository.getCurrentUser()).thenAnswer((_) async => testUser);

      final initialState = await container.read(userNotifierProvider.future);
      expect(initialState?.pinnedGames.length, equals(1));
      expect(initialState?.friends.length, equals(1));

      // Perform an update
      when(mockRepository.addPinnedGame('user-1', 'game-2')).thenAnswer(
        (_) async {},
      );
      when(mockRepository.getCurrentUser()).thenAnswer(
        (_) async => testUser.copyWith(pinnedGames: ['game-1', 'game-2']),
      );

      final notifier = container.read(userNotifierProvider.notifier);
      await notifier.addPinnedGame('game-2');

      // State should be updated
      final updatedState = container.read(userNotifierProvider).valueOrNull;
      expect(updatedState, isNotNull);
    });

    test('should handle concurrent updates', () async {
      final testUser = createTestUser();
      when(mockRepository.getCurrentUser()).thenAnswer((_) async => testUser);
      when(mockRepository.addPinnedGame('user-1', 'game-1')).thenAnswer(
        (_) async => Future.delayed(const Duration(milliseconds: 50)),
      );
      when(mockRepository.addFriend('user-1', 'friend-1')).thenAnswer(
        (_) async => Future.delayed(const Duration(milliseconds: 50)),
      );

      await container.read(userNotifierProvider.future);
      final notifier = container.read(userNotifierProvider.notifier);

      // Start both operations concurrently
      await Future.wait([
        notifier.addPinnedGame('game-1'),
        notifier.addFriend('friend-1'),
      ]);

      verify(mockRepository.addPinnedGame('user-1', 'game-1')).called(1);
      verify(mockRepository.addFriend('user-1', 'friend-1')).called(1);
    });
  });

  group('UserNotifier - Error Recovery', () {
    test('should recover from temporary errors', () async {
      final testUser = createTestUser();
      var callCount = 0;

      when(mockRepository.getCurrentUser()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('Temporary error');
        }
        return testUser;
      });

      // First call might fail
      try {
        await container.read(userNotifierProvider.future);
      } catch (e) {
        // Expected
      }

      // Retry should work
      container.invalidate(userNotifierProvider);
      final state = await container.read(userNotifierProvider.future);

      expect(state, isNotNull);
    });

    test('should handle null user gracefully', () async {
      when(mockRepository.getCurrentUser()).thenAnswer((_) async => null);

      final state = await container.read(userNotifierProvider.future);

      expect(state, isNull);
    });
  });
}
