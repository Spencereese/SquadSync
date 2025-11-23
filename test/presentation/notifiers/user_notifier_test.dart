import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/entities/app_user.dart';
import 'package:squad_sync/presentation/notifiers/user_notifier.dart';
import 'package:squad_sync/core/injection.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late MockGetCurrentUser mockGetCurrentUser;
  late MockUpdateDisplayName mockUpdateDisplayName;
  late MockUpdateProfileImage mockUpdateProfileImage;
  late MockBlockUser mockBlockUser;
  late MockUnblockUser mockUnblockUser;
  late MockAddPinnedGame mockAddPinnedGame;
  late MockRemovePinnedGame mockRemovePinnedGame;

  setUp(() {
    mockGetCurrentUser = MockGetCurrentUser();
    mockUpdateDisplayName = MockUpdateDisplayName();
    mockUpdateProfileImage = MockUpdateProfileImage();
    mockBlockUser = MockBlockUser();
    mockUnblockUser = MockUnblockUser();
    mockAddPinnedGame = MockAddPinnedGame();
    mockRemovePinnedGame = MockRemovePinnedGame();
  });

  group('UserNotifier', () {
    final testUser = AppUser(
      uid: 'test-uid',
      displayName: 'Test User',
      profileImage: 'https://example.com/image.jpg',
      preferredModes: {},
      userBlocks: {},
      pinnedGames: [{'id': 'game1', 'name': 'Game One'}],
      mutedGames: {},
      hasRatedGame: {},
      dailyRatings: {},
      allTimeRatings: {},
      currentStreaks: {},
      complaints: {},
      achievements: {},
      bannedUsers: {},
      lastSync: DateTime.now(),
    );

    final updatedUser = testUser.copyWith(displayName: 'Updated Name');

    group('build - initialization', () {
      testWidgets('should load current user successfully', (WidgetTester tester) async {
        when(mockGetCurrentUser()).thenAnswer((_) async => testUser);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: FutureBuilder(
                      future: notifier.build().first,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return Text('Done');
                        }
                        return const CircularProgressIndicator();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Done'), findsOneWidget);
      });

      testWidgets('should handle null user (not authenticated)', (WidgetTester tester) async {
        when(mockGetCurrentUser()).thenAnswer((_) async => null);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: FutureBuilder(
                      future: notifier.build().first,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return Text('Done');
                        }
                        return const CircularProgressIndicator();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Done'), findsOneWidget);
      });

      testWidgets('should handle initialization errors', (WidgetTester tester) async {
        when(mockGetCurrentUser()).thenThrow(Exception('Network error'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: FutureBuilder(
                      future: notifier.build().first,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }
                        return const CircularProgressIndicator();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Error: Exception: Network error'), findsOneWidget);
      });
    });

    group('updateDisplayName', () {
      testWidgets('should update name and reload user successfully', (WidgetTester tester) async {
        when(mockGetCurrentUser()).thenAnswer((_) async => testUser);
        when(mockUpdateDisplayName('Updated Name')).thenAnswer((_) async => Future.value());
        when(mockGetCurrentUser()).thenAnswer((_) async => updatedUser); // Return updated user on refresh

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
              updateDisplayNameProvider.overrideWith((ref) => mockUpdateDisplayName),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: ElevatedButton(
                      onPressed: () async {
                        await notifier.updateDisplayName('Updated Name');
                      },
                      child: const Text('Update'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        verify(mockUpdateDisplayName('Updated Name')).called(1);
        verify(mockGetCurrentUser()).called(2); // Initial load + refresh
      });

      testWidgets('should handle special characters in display name', (WidgetTester tester) async {
        when(mockGetCurrentUser()).thenAnswer((_) async => testUser);
        when(mockUpdateDisplayName('Test User 🚀🎮')).thenAnswer((_) async => Future.value());
        when(mockGetCurrentUser()).thenAnswer((_) async => testUser.copyWith(displayName: 'Test User 🚀🎮'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
              updateDisplayNameProvider.overrideWith((ref) => mockUpdateDisplayName),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: ElevatedButton(
                      onPressed: () async {
                        await notifier.updateDisplayName('Test User 🚀🎮');
                      },
                      child: const Text('Update'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        verify(mockUpdateDisplayName('Test User 🚀🎮')).called(1);
      });

      testWidgets('should handle update errors and preserve original state', (WidgetTester tester) async {
        when(mockGetCurrentUser()).thenAnswer((_) async => testUser);
        when(mockUpdateDisplayName('Updated Name'))
            .thenThrow(Exception('Permission denied'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
              updateDisplayNameProvider.overrideWith((ref) => mockUpdateDisplayName),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: ElevatedButton(
                      onPressed: () async {
                        try {
                          await notifier.updateDisplayName('Updated Name');
                        } catch (e) {
                          // Error handled
                        }
                      },
                      child: const Text('Update'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        verify(mockUpdateDisplayName('Updated Name')).called(1);
        // Should not refresh user due to error
        verify(mockGetCurrentUser()).called(1); // Only initial load
      });
    });

    group('updateProfileImage', () {
      testWidgets('should update image and reload user successfully', (WidgetTester tester) async {
        when(mockGetCurrentUser()).thenAnswer((_) async => testUser);
        when(mockUpdateProfileImage('new-image-url')).thenAnswer((_) async => Future.value());
        when(mockGetCurrentUser()).thenAnswer((_) async => testUser.copyWith(profileImage: 'new-image-url'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
              updateProfileImageProvider.overrideWith((ref) => mockUpdateProfileImage),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: ElevatedButton(
                      onPressed: () async {
                        await notifier.updateProfileImage('new-image-url');
                      },
                      child: const Text('Update Image'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Update Image'));
        await tester.pumpAndSettle();

        verify(mockUpdateProfileImage('new-image-url')).called(1);
        verify(mockGetCurrentUser()).called(2);
      });
    });

    group('blockUser', () {
      testWidgets('should block user and update blocked list', (WidgetTester tester) async {
        when(mockGetCurrentUser()).thenAnswer((_) async => testUser);
        when(mockBlockUser('new-blocked-user')).thenAnswer((_) async => Future.value());
        when(mockGetCurrentUser()).thenAnswer((_) async =>
            testUser.copyWith(userBlocks: {'new-blocked-user': {}}));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
              blockUserProvider.overrideWith((ref) => mockBlockUser),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: ElevatedButton(
                      onPressed: () async {
                        await notifier.blockUser('new-blocked-user');
                      },
                      child: const Text('Block User'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Block User'));
        await tester.pumpAndSettle();

        verify(mockBlockUser('new-blocked-user')).called(1);
        verify(mockGetCurrentUser()).called(2);
      });
    });

    group('unblockUser', () {
      testWidgets('should unblock user and update blocked list', (WidgetTester tester) async {
        final userWithBlocks = testUser.copyWith(userBlocks: {'blocked-user': {}});
        when(mockGetCurrentUser()).thenAnswer((_) async => userWithBlocks);
        when(mockUnblockUser('blocked-user')).thenAnswer((_) async => Future.value());
        when(mockGetCurrentUser()).thenAnswer((_) async =>
            testUser.copyWith(userBlocks: {}));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
              unblockUserProvider.overrideWith((ref) => mockUnblockUser),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: ElevatedButton(
                      onPressed: () async {
                        await notifier.unblockUser('blocked-user');
                      },
                      child: const Text('Unblock User'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Unblock User'));
        await tester.pumpAndSettle();

        verify(mockUnblockUser('blocked-user')).called(1);
        verify(mockGetCurrentUser()).called(2);
      });
    });

    group('addPinnedGame', () {
      testWidgets('should add game to pinned games list', (WidgetTester tester) async {
        when(mockGetCurrentUser()).thenAnswer((_) async => testUser);
        final newGame = {'id': 'game2', 'name': 'Game Two'};
        when(mockAddPinnedGame(newGame)).thenAnswer((_) async => Future.value());
        when(mockGetCurrentUser()).thenAnswer((_) async =>
            testUser.copyWith(pinnedGames: [
              {'id': 'game1', 'name': 'Game One'},
              newGame
            ]));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
              addPinnedGameProvider.overrideWith((ref) => mockAddPinnedGame),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: ElevatedButton(
                      onPressed: () async {
                        await notifier.addPinnedGame(newGame);
                      },
                      child: const Text('Add Game'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Add Game'));
        await tester.pumpAndSettle();

        verify(mockAddPinnedGame(newGame)).called(1);
        verify(mockGetCurrentUser()).called(2);
      });
    });

    group('removePinnedGame', () {
      testWidgets('should remove game from pinned games list', (WidgetTester tester) async {
        when(mockGetCurrentUser()).thenAnswer((_) async => testUser);
        when(mockRemovePinnedGame('Game One')).thenAnswer((_) async => Future.value());
        when(mockGetCurrentUser()).thenAnswer((_) async =>
            testUser.copyWith(pinnedGames: []));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getCurrentUserProvider.overrideWith((ref) => mockGetCurrentUser),
              removePinnedGameProvider.overrideWith((ref) => mockRemovePinnedGame),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final notifier = container.read(userNotifierProvider.notifier);
                return MaterialApp(
                  home: Scaffold(
                    body: ElevatedButton(
                      onPressed: () async {
                        await notifier.removePinnedGame('Game One');
                      },
                      child: const Text('Remove Game'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Remove Game'));
        await tester.pumpAndSettle();

        verify(mockRemovePinnedGame('Game One')).called(1);
        verify(mockGetCurrentUser()).called(2);
      });
    });
  });
}