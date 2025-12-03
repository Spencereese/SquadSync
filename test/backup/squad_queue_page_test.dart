// Commented out - SquadNotifier deleted during squad refactor migration
/*
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cod_squad_app/presentation/screens/squad_queue_page.dart';
import 'package:cod_squad_app/presentation/notifiers/squad_notifier.dart';
import 'package:cod_squad_app/domain/entities/squad.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late MockSquadRepository mockRepository;

  setUp(() {
    mockRepository = MockSquadRepository();
  });

  final testSquad = Squad(
    id: 'squad123',
    name: 'Test Squad',
    memberUids: ['uid1', 'uid2'],
    gameName: 'cod',
    maxSpots: 4,
    createdBy: 'uid1',
    createdAt: DateTime.now(),
    spots: [null, 'uid1', null, null],
    spotTimers: [null, null, null, null],
    viewers: [],
    statuses: {},
    isActive: true,
  );

  group('SquadQueuePage', () {
    testWidgets('should display squad name and game', (tester) async {
      // Arrange
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(testSquad));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Assert
      expect(find.text('Test Squad'), findsOneWidget);
      expect(find.text('cod'), findsOneWidget);
    });

    testWidgets('should display spot grid with correct number of spots', (tester) async {
      // Arrange
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(testSquad));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Assert - should have 4 spot buttons
      expect(find.byType(ElevatedButton), findsNWidgets(4));
    });

    testWidgets('should show claimed spot with user name', (tester) async {
      // Arrange
      final squadWithClaimedSpot = testSquad.copyWith(
        spots: [null, 'uid1', null, null],
      );
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(squadWithClaimedSpot));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Assert - spot 2 should show as claimed
      expect(find.text('Spot 2: uid1'), findsOneWidget);
    });

    testWidgets('should show available spot as claimable', (tester) async {
      // Arrange
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(testSquad));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Assert - spot 1 should show as available
      expect(find.text('Claim Spot 1'), findsOneWidget);
    });

    testWidgets('should handle spot claiming', (tester) async {
      // Arrange
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(testSquad));
      when(mockRepository.assignSpot('squad123', 0, 'current_user')).thenAnswer((_) async => const Right(unit));
      when(mockRepository.startSpotTimer('squad123', 0, Duration(minutes: 5))).thenAnswer((_) async => const Right(unit));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Find and tap the first available spot
      final claimButton = find.text('Claim Spot 1');
      expect(claimButton, findsOneWidget);
      await tester.tap(claimButton);
      await tester.pump(); // Allow state changes

      // Assert
      verify(mockRepository.assignSpot('squad123', 0, 'current_user')).called(1);
      verify(mockRepository.startSpotTimer('squad123', 0, Duration(minutes: 5))).called(1);
    });

    testWidgets('should show timer countdown for claimed spots', (tester) async {
      // Arrange
      final timerStartTime = DateTime.now().subtract(Duration(minutes: 2));
      final squadWithTimer = testSquad.copyWith(
        spots: [null, 'uid1', null, null],
        spotTimers: [
          null,
          {
            'userId': 'uid1',
            'startTime': timerStartTime.toIso8601String(),
            'duration': Duration(minutes: 5).inMilliseconds,
          },
          null,
          null,
        ],
      );
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(squadWithTimer));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Assert - should show remaining time (approximately 3 minutes)
      expect(find.textContaining('3:'), findsOneWidget); // Timer countdown
    });

    testWidgets('should allow canceling timer', (tester) async {
      // Arrange
      final timerStartTime = DateTime.now().subtract(Duration(minutes: 2));
      final squadWithTimer = testSquad.copyWith(
        spots: [null, 'current_user', null, null],
        spotTimers: [
          null,
          {
            'userId': 'current_user',
            'startTime': timerStartTime.toIso8601String(),
            'duration': Duration(minutes: 5).inMilliseconds,
          },
          null,
          null,
        ],
      );
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(squadWithTimer));
      when(mockRepository.cancelSpotTimer('squad123', 1)).thenAnswer((_) async => const Right(unit));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Find and tap the cancel timer button
      final cancelButton = find.text('Cancel Timer');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump(); // Allow state changes

      // Assert
      verify(mockRepository.cancelSpotTimer('squad123', 1)).called(1);
    });

    testWidgets('should show leave squad option', (tester) async {
      // Arrange
      final squadWithCurrentUser = testSquad.copyWith(
        memberUids: ['uid1', 'current_user'],
      );
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(squadWithCurrentUser));
      when(mockRepository.leaveSquad('squad123', 'current_user')).thenAnswer((_) async => const Right(unit));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Find and tap the leave squad button
      final leaveButton = find.text('Leave Squad');
      expect(leaveButton, findsOneWidget);
      await tester.tap(leaveButton);
      await tester.pump(); // Allow state changes

      // Assert
      verify(mockRepository.leaveSquad('squad123', 'current_user')).called(1);
    });

    testWidgets('should show join squad option for non-members', (tester) async {
      // Arrange
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(testSquad));
      when(mockRepository.joinSquad('squad123', 'current_user')).thenAnswer((_) async => const Right(unit));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Find and tap the join squad button
      final joinButton = find.text('Join Squad');
      expect(joinButton, findsOneWidget);
      await tester.tap(joinButton);
      await tester.pump(); // Allow state changes

      // Assert
      verify(mockRepository.joinSquad('squad123', 'current_user')).called(1);
    });

    testWidgets('should display loading indicator during operations', (tester) async {
      // Arrange
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => const AsyncValue.loading());

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display error message when loading fails', (tester) async {
      // Arrange
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.error('Failed to load squad'));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Assert
      expect(find.text('Failed to load squad'), findsOneWidget);
    });
  });
}
*/
