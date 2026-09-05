import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:squad_sync/presentation/notifiers/timer_management_notifier.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';
import 'package:squad_sync/services/timer_service.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([LobbyRepository, TimerServiceNotifier])
import 'timer_management_notifier_test.mocks.dart';

void main() {
  group('TimerManagementNotifier', () {
    late ProviderContainer container;
    late MockLobbyRepository mockRepository;

    setUp(() {
      mockRepository = MockLobbyRepository();

      container = ProviderContainer(
        overrides: [
          lobbyRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with empty state', () async {
      final notifier = container.read(timerManagementNotifierProvider.notifier);
      final state =
          await container.read(timerManagementNotifierProvider.future);

      expect(state.spotTimerStates, isEmpty);
      expect(state.peacockTimerStates, isEmpty);
      expect(state.gameSpotTimers, isEmpty);
      expect(state.peacockTimers, isEmpty);
      expect(state.isProcessing, false);
    });

    test('should start spot timer', () async {
      // TODO: Implement test for starting spot timer
      // Test should verify:
      // - Timer is started in TimerService
      // - Repository is called with correct parameters
      // - State is updated with new timer
    });

    test('should stop spot timer', () async {
      // TODO: Implement test for stopping spot timer
      // Test should verify:
      // - Timer is stopped in TimerService
      // - State is updated to remove timer
    });

    test('should process expired timers', () async {
      // TODO: Implement test for processing expired timers
      // Test should verify:
      // - Repository processExpiredTimers is called
      // - isProcessing flag is set during processing
      // - State is updated after processing completes
    });

    test('should reset timers for a game', () async {
      // TODO: Implement test for resetting game timers
      // Test should verify:
      // - All timers for the game are stopped
      // - State is updated to reflect timer removal
    });

    test('should get spot timer remaining time', () async {
      // TODO: Implement test for getting remaining time
      // Test should verify:
      // - Correct timer key is used
      // - Remaining duration is returned
      // - Null is returned if timer doesn't exist
    });

    test('should check if user has active timer', () async {
      // TODO: Implement test for checking active timer
      // Test should verify:
      // - Returns true for active timers (> 0 seconds)
      // - Returns false for expired or non-existent timers
    });

    test('should get all active timers for a game', () async {
      // TODO: Implement test for getting all game timers
      // Test should verify:
      // - Only timers for specified game are returned
      // - Only active timers (> 0 seconds) are included
      // - Timer keys are correctly formatted
    });

    test('should handle timer subscription updates', () async {
      // TODO: Implement test for subscription handling
      // Test should verify:
      // - Subscription is created when lobby is set
      // - Subscription is cancelled on dispose
      // - State updates when subscription emits new data
    });

    test('cleanupExpiredPeacockTimers expires display; server assigns',
        () async {
      PeacockAssignmentTracker.resetInstance();
      addTearDown(PeacockAssignmentTracker.resetInstance);
      when(mockRepository.processExpiredTimers()).thenAnswer((_) async {});
      final tracker = PeacockAssignmentTracker.instance;
      tracker.assignSpot('expired-user', lobbyId: 'lobby-9');
      tracker.joinQueue('next-user');

      var processCalled = false;
      tracker.queueProcessor = ({
        String? assignedUserId,
        String? lobbyId,
        String? gameName,
        String? notificationId,
      }) async {
        processCalled = true;
        if (assignedUserId != null) {
          tracker.assignSpot(assignedUserId, lobbyId: lobbyId);
        }
        return assignedUserId;
      };

      final notifier = container.read(timerManagementNotifierProvider.notifier);
      await container.read(timerManagementNotifierProvider.future);
      notifier.updateTimerStates(peacockTimers: {
        'expired-user': Duration.zero,
        'next-user': const Duration(seconds: 45),
      });

      await notifier.cleanupExpiredPeacockTimers();

      expect(
        tracker.stateFor('expired-user').phase,
        PeacockAssignmentPhase.idle,
      );
      expect(processCalled, isFalse);
      expect(
        tracker.stateFor('next-user').phase,
        PeacockAssignmentPhase.queued,
      );
      verify(mockRepository.processExpiredTimers()).called(1);
      verifyNever(mockRepository.processPeacockQueue());
    });

    test('cleanupExpiredPeacockTimers does not assign next locally', () async {
      PeacockAssignmentTracker.resetInstance();
      addTearDown(PeacockAssignmentTracker.resetInstance);
      when(mockRepository.processExpiredTimers()).thenAnswer((_) async {});
      final tracker = PeacockAssignmentTracker.instance;
      tracker.assignSpot('expired-user', lobbyId: 'lobby-9');
      tracker.joinQueue('next-user');

      final notifier = container.read(timerManagementNotifierProvider.notifier);
      await container.read(timerManagementNotifierProvider.future);
      notifier.updateTimerStates(peacockTimers: {
        'expired-user': Duration.zero,
      });

      await notifier.cleanupExpiredPeacockTimers();

      expect(
        tracker.stateFor('expired-user').phase,
        PeacockAssignmentPhase.idle,
      );
      expect(
        tracker.stateFor('next-user').phase,
        PeacockAssignmentPhase.queued,
      );
      verify(mockRepository.processExpiredTimers()).called(1);
      verifyNever(mockRepository.processPeacockQueue());
    });

    test('should sync timer data with local storage', () async {
      // TODO: Implement test for timer data sync
      // Test should verify:
      // - gameSpotTimers state is updated
      // - Local storage is updated with timer data
    });
  });

  group('Timer convenience providers', () {
    test('spotTimerRemainingProvider should return correct duration', () async {
      // TODO: Implement test for spotTimerRemainingProvider
    });

    test('hasActiveTimerProvider should return correct boolean', () async {
      // TODO: Implement test for hasActiveTimerProvider
    });
  });
}
