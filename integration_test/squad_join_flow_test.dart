import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/main.dart';
import 'package:squad_sync/presentation/notifiers/squad_notifier.dart';
import 'package:squad_sync/domain/entities/squad.dart';
import '../test/helpers/mocks.mocks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  group('Squad Join Flow E2E', () {
    testWidgets('complete squad discovery and join flow', (tester) async {
      // Arrange - Mock successful squad operations
      when(mockRepository.getUserSquads('current_user')).thenAnswer((_) async => const AsyncValue.data([]));
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(testSquad));
      when(mockRepository.joinSquad('squad123', 'current_user')).thenAnswer((_) async => const Right(unit));
      when(mockRepository.assignSpot('squad123', 0, 'current_user')).thenAnswer((_) async => const Right(unit));
      when(mockRepository.startSpotTimer('squad123', 0, Duration(minutes: 5))).thenAnswer((_) async => const Right(unit));

      // Act - Launch the app
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Squad tab
      final squadTab = find.text('Squad');
      expect(squadTab, findsOneWidget);
      await tester.tap(squadTab);
      await tester.pumpAndSettle();

      // Verify empty state is shown
      expect(find.text('No squads found'), findsOneWidget);
      expect(find.text('Create your first squad to get started!'), findsOneWidget);

      // Simulate discovering a squad (through deep link or QR code)
      // In a real app, this would come from a deep link handler
      final squadQueuePage = SquadQueuePage(squadId: 'squad123');

      // Navigate to squad queue page
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: MaterialApp(
            home: squadQueuePage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Squad details are displayed
      expect(find.text('Test Squad'), findsOneWidget);
      expect(find.text('cod'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNWidgets(4)); // 4 spot buttons

      // Verify spot status
      expect(find.text('Claim Spot 1'), findsOneWidget); // Spot 1 available
      expect(find.text('Spot 2: uid1'), findsOneWidget); // Spot 2 claimed

      // Join the squad
      final joinButton = find.text('Join Squad');
      expect(joinButton, findsOneWidget);
      await tester.tap(joinButton);
      await tester.pumpAndSettle();

      // Verify join operation was called
      verify(mockRepository.joinSquad('squad123', 'current_user')).called(1);

      // Claim a spot
      final claimButton = find.text('Claim Spot 1');
      expect(claimButton, findsOneWidget);
      await tester.tap(claimButton);
      await tester.pumpAndSettle();

      // Verify spot claiming operations were called
      verify(mockRepository.assignSpot('squad123', 0, 'current_user')).called(1);
      verify(mockRepository.startSpotTimer('squad123', 0, Duration(minutes: 5))).called(1);

      // Verify UI updates to show claimed spot
      await tester.pump(); // Allow state updates
      expect(find.text('Spot 1: current_user'), findsOneWidget);

      // Verify timer is running
      expect(find.textContaining('4:'), findsOneWidget); // Timer countdown

      // Test timer cancellation
      final cancelButton = find.text('Cancel Timer');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Verify timer cancellation was called
      verify(mockRepository.cancelSpotTimer('squad123', 0)).called(1);

      // Test leaving the squad
      final leaveButton = find.text('Leave Squad');
      expect(leaveButton, findsOneWidget);
      await tester.tap(leaveButton);
      await tester.pumpAndSettle();

      // Verify leave operation was called
      verify(mockRepository.leaveSquad('squad123', 'current_user')).called(1);
    });

    testWidgets('handle squad join flow errors gracefully', (tester) async {
      // Arrange - Mock failed operations
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(testSquad));
      when(mockRepository.joinSquad('squad123', 'current_user')).thenAnswer((_) async => Left(ServerFailure('Network error')));

      // Act - Navigate to squad queue page
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: MaterialApp(
            home: const SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Attempt to join squad
      final joinButton = find.text('Join Squad');
      expect(joinButton, findsOneWidget);
      await tester.tap(joinButton);
      await tester.pumpAndSettle();

      // Assert - Error is handled gracefully (UI should show error state)
      verify(mockRepository.joinSquad('squad123', 'current_user')).called(1);
      // In a real app, you'd check for error snackbar or dialog
    });

    testWidgets('handle spot claiming with timer expiration', (tester) async {
      // Arrange - Mock timer expiration scenario
      final expiredTimerStart = DateTime.now().subtract(Duration(minutes: 6)); // Timer expired
      final squadWithExpiredTimer = testSquad.copyWith(
        spots: [null, 'current_user', null, null],
        spotTimers: [
          null,
          {
            'userId': 'current_user',
            'startTime': expiredTimerStart.toIso8601String(),
            'duration': Duration(minutes: 5).inMilliseconds,
          },
          null,
          null,
        ],
      );

      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(squadWithExpiredTimer));
      when(mockRepository.assignSpot('squad123', 1, null)).thenAnswer((_) async => const Right(unit)); // Auto-clear expired spot

      // Act - Navigate to squad queue page
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: MaterialApp(
            home: const SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Expired timer should trigger spot clearing
      verify(mockRepository.assignSpot('squad123', 1, null)).called(1);
      expect(find.text('Claim Spot 2'), findsOneWidget); // Spot should be available again
    });

    testWidgets('handle concurrent spot claiming', (tester) async {
      // Arrange - Mock race condition scenario
      when(mockRepository.getSquad('squad123')).thenAnswer((_) async => AsyncValue.data(testSquad));
      when(mockRepository.assignSpot('squad123', 0, 'current_user')).thenAnswer((_) async => Left(ServerFailure('Spot already claimed')));

      // Act - Navigate to squad queue page and attempt to claim spot
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: MaterialApp(
            home: const SquadQueuePage(squadId: 'squad123'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Attempt to claim spot
      final claimButton = find.text('Claim Spot 1');
      expect(claimButton, findsOneWidget);
      await tester.tap(claimButton);
      await tester.pumpAndSettle();

      // Assert - Concurrent claim failure is handled
      verify(mockRepository.assignSpot('squad123', 0, 'current_user')).called(1);
      // In a real app, you'd check for error handling UI
    });
  });
}