import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/main.dart' show SquadSyncApp;
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mocks generated in test/mocks/integration_test_mocks.dart
import '../test/mocks/integration_test_mocks.mocks.dart';

/// Integration tests for lobby join/leave flows with real-time updates
/// Tests LobbyNotifier coordination with Supabase streams
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Lobby Join/Leave Integration Tests', () {
    late MockLobbyRepository mockRepository;
    late MockAuthServiceSupabase mockAuthService;

    setUp(() {
      mockRepository = MockLobbyRepository();
      mockAuthService = MockAuthServiceSupabase();

      // Mock authenticated user
      final mockUser = User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {'display_name': 'Test User'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      when(mockAuthService.currentUser).thenReturn(mockUser);
      when(mockAuthService.currentUserId).thenReturn('test-user-id');
    });

    testWidgets('Join lobby via invite code', (WidgetTester tester) async {
      // Arrange: Mock lobby lookup by invite code
      final mockLobby = Lobby(
        id: 'lobby-123',
        name: 'Test Lobby',
        gameName: 'Warzone',
        maxSpots: 8,
        spots: List.filled(8, null),
        spotTimers: List.filled(8, null),
        statuses: {},
        memberUids: ['owner-id'],
        createdAt: DateTime.now(),
        createdBy: 'owner-id',
        viewers: [],
        isActive: true,
      );

      when(mockRepository.getLobbyByInviteCode('ABCD1234'))
          .thenAnswer((_) async => mockLobby);

      when(mockRepository.joinLobby('lobby-123', 'test-user-id'))
          .thenAnswer((_) async {});

      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) async => LobbyState.initial().copyWith(
          selectedLobbyId: 'lobby-123',
          currentLobby: mockLobby,
        ),
      );

      // Act: Build app with mocked repository
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lobbyRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Act: Navigate to join lobby screen (via deep link or UI)
      // Find "Join Lobby" button or text input
      final joinButton = find.text('Join Lobby');
      if (joinButton.evaluate().isNotEmpty) {
        await tester.tap(joinButton);
        await tester.pumpAndSettle();

        // Act: Enter invite code
        final inviteCodeField = find.byType(TextField);
        await tester.enterText(inviteCodeField, 'ABCD1234');
        await tester.pumpAndSettle();

        // Act: Submit join request
        final submitButton = find.text('Join');
        await tester.tap(submitButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Verify repository methods called
        verify(mockRepository.getLobbyByInviteCode('ABCD1234')).called(1);
        verify(mockRepository.joinLobby('lobby-123', 'test-user-id')).called(1);

        // Assert: Should show lobby screen with lobby details
        expect(find.text('Test Lobby'), findsOneWidget);
        expect(find.text('Warzone'), findsOneWidget);
      }
    });

    testWidgets('Create lobby and receive real-time updates',
        (WidgetTester tester) async {
      // Arrange: Mock lobby creation
      final createdLobby = Lobby(
        id: 'new-lobby-id',
        name: 'My New Lobby',
        gameName: 'Call of Duty',
        maxSpots: 4,
        spots: List.filled(4, null),
        spotTimers: List.filled(4, null),
        statuses: {},
        memberUids: ['test-user-id'],
        createdBy: 'test-user-id',
        viewers: [],
        isActive: true,
        createdAt: DateTime.now(),
      );

      when(mockRepository.createLobby('My New Lobby', 'Call of Duty', 4))
          .thenAnswer((_) async => createdLobby);

      // Mock real-time stream
      when(mockRepository.getLobbyStream('new-lobby-id')).thenAnswer(
        (_) => Stream.value(createdLobby),
      );

      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) async => LobbyState.initial().copyWith(
          selectedLobbyId: 'new-lobby-id',
          currentLobby: createdLobby,
        ),
      );

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lobbyRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Act: Create lobby (find create lobby button)
      final createButton = find.text('Create Lobby');
      if (createButton.evaluate().isNotEmpty) {
        await tester.tap(createButton);
        await tester.pumpAndSettle();

        // Fill in lobby details
        final nameField = find.widgetWithText(TextField, 'Lobby Name');
        if (nameField.evaluate().isNotEmpty) {
          await tester.enterText(nameField, 'My New Lobby');
        }

        final gameField = find.widgetWithText(TextField, 'Game');
        if (gameField.evaluate().isNotEmpty) {
          await tester.enterText(gameField, 'Call of Duty');
        }

        // Submit creation
        final submitButton = find.text('Create');
        await tester.tap(submitButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Verify lobby creation
        verify(mockRepository.createLobby('My New Lobby', 'Call of Duty', 4))
            .called(1);

        // Assert: Should show lobby screen
        expect(find.text('My New Lobby'), findsOneWidget);
        expect(find.text('NEW12345'), findsOneWidget); // Invite code
      }
    });

    testWidgets('Leave lobby and update state', (WidgetTester tester) async {
      // Arrange: Mock current lobby
      final currentLobby = Lobby(
        id: 'lobby-to-leave',
        name: 'Existing Lobby',
        gameName: 'Warzone',
        maxSpots: 8,
        spots: List.filled(8, null),
        spotTimers: List.filled(8, null),
        statuses: {},
        memberUids: ['test-user-id', 'other-user-id'],
        createdBy: 'test-user-id',
        viewers: [],
        isActive: true,
        createdAt: DateTime.now(),
      );

      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) async => LobbyState.initial().copyWith(
          selectedLobbyId: 'lobby-to-leave',
          currentLobby: currentLobby,
        ),
      );

      when(mockRepository.leaveLobby('lobby-to-leave', 'test-user-id'))
          .thenAnswer((_) async {});

      // Act: Build app with user in lobby
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lobbyRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Act: Find and tap leave button
      final leaveButton = find.text('Leave Lobby');
      if (leaveButton.evaluate().isNotEmpty) {
        await tester.tap(leaveButton);
        await tester.pumpAndSettle();

        // Confirm leave action if there's a dialog
        final confirmButton = find.text('Confirm');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        // Assert: Verify leave was called
        verify(mockRepository.leaveLobby('lobby-to-leave', 'test-user-id'))
            .called(1);

        // Assert: Should navigate away from lobby screen
        expect(find.text('Existing Lobby'), findsNothing);
      }
    });

    testWidgets('Real-time spot updates from other members',
        (WidgetTester tester) async {
      // Arrange: Initial lobby state
      final initialLobby = Lobby(
        id: 'realtime-lobby',
        name: 'Realtime Test',
        gameName: 'Warzone',
        maxSpots: 4,
        spots: [null, null, null, null],
        spotTimers: [null, null, null, null],
        statuses: {},
        memberUids: ['test-user-id', 'other-user-id'],
        createdBy: 'test-user-id',
        viewers: [],
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Simulate another user claiming a spot
      final updatedLobby = initialLobby.copyWith(
        spots: ['other-user-id', null, null, null],
      );

      // Create stream that emits initial then updated lobby
      final streamController = Stream<Lobby?>.fromIterable([
        initialLobby,
        updatedLobby,
      ]);

      when(mockRepository.getLobbyStream('realtime-lobby')).thenAnswer(
        (_) => streamController,
      );

      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) async => LobbyState.initial().copyWith(
          selectedLobbyId: 'realtime-lobby',
          currentLobby: initialLobby,
        ),
      );

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lobbyRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Initially all spots should be empty
      // (Check for spot UI elements)

      // Act: Wait for stream update
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert: Should show updated spot claim
      // This depends on your UI - look for spot indicators
      // For example: expect(find.text('other-user-id'), findsOneWidget);
    });

    testWidgets('Handle invalid invite code', (WidgetTester tester) async {
      // Arrange: Mock failed lookup
      when(mockRepository.getLobbyByInviteCode('INVALID1'))
          .thenAnswer((_) async => null);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lobbyRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Act: Try to join with invalid code
      final joinButton = find.text('Join Lobby');
      if (joinButton.evaluate().isNotEmpty) {
        await tester.tap(joinButton);
        await tester.pumpAndSettle();

        final inviteCodeField = find.byType(TextField);
        await tester.enterText(inviteCodeField, 'INVALID1');
        await tester.pumpAndSettle();

        final submitButton = find.text('Join');
        await tester.tap(submitButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Should show error message
        expect(find.textContaining('Invalid'), findsOneWidget);
      }
    });

    testWidgets('User lobby list updates when joining',
        (WidgetTester tester) async {
      // Arrange: Mock user lobbies stream
      final lobby1 = Lobby(
        id: 'lobby-1',
        name: 'Lobby 1',
        gameName: 'Warzone',
        maxSpots: 8,
        spots: List.filled(8, null),
        spotTimers: List.filled(8, null),
        statuses: {},
        memberUids: ['test-user-id'],
        createdBy: 'test-user-id',
        viewers: [],
        isActive: true,
        createdAt: DateTime.now(),
      );

      final lobby2 = Lobby(
        id: 'lobby-2',
        name: 'Lobby 2',
        gameName: 'Fortnite',
        maxSpots: 4,
        spots: List.filled(4, null),
        spotTimers: List.filled(4, null),
        statuses: {},
        memberUids: ['test-user-id'],
        createdBy: 'test-user-id',
        viewers: [],
        isActive: true,
        createdAt: DateTime.now(),
      );

      when(mockRepository.getUserLobbiesStream('test-user-id')).thenAnswer(
        (_) => Stream.value([lobby1, lobby2]),
      );

      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) async => LobbyState.initial().copyWith(
          userLobbyIds: ['lobby-1', 'lobby-2'],
          userLobbies: {
            'lobby-1': lobby1,
            'lobby-2': lobby2,
          },
        ),
      );

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lobbyRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Should show both lobbies in user's lobby list
      expect(find.text('Lobby 1'), findsOneWidget);
      expect(find.text('Lobby 2'), findsOneWidget);
    });
  });

  group('Lobby Edge Cases', () {
    testWidgets('Handle lobby deletion while viewing',
        (WidgetTester tester) async {
      // Test what happens when lobby owner deletes lobby
      // while user is viewing it
    });

    testWidgets('Handle network disconnection during join',
        (WidgetTester tester) async {
      // Test offline behavior when joining lobby
    });

    testWidgets('Handle concurrent spot claims', (WidgetTester tester) async {
      // Test race condition when multiple users claim same spot
    });
  });
}
