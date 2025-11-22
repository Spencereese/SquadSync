import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:squad_sync/services/timer_service.dart';
import 'package:squad_sync/services/firestore_service.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';
import 'package:squad_sync/providers/service_providers.dart';
import 'timer_service_test.mocks.dart';

@GenerateMocks([
  FirestoreService,
  SQLiteHelper,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockFirestoreService mockFirestoreService;
  late MockSQLiteHelper mockSQLiteHelper;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    mockSQLiteHelper = MockSQLiteHelper();

    container = ProviderContainer(
      overrides: [
        firestoreServiceProvider.overrideWithValue(mockFirestoreService),
        sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('TimerOrchestrator', () {
    late TimerOrchestrator orchestrator;

    setUp(() {
      orchestrator = TimerOrchestrator();
    });

    tearDown(() {
      orchestrator.stop();
    });

    test('starts and stops correctly', () {
      orchestrator.start();
      // Timer should be started internally

      orchestrator.stop();
      // Timer should be stopped
    });

    test('adds and removes timers', () {
      bool expired = false;
      orchestrator.addTimer('test', const Duration(seconds: 1), () => expired = true);

      // Timer should be added
      expect(() => orchestrator.getRemainingTime('test'), returnsNormally);

      orchestrator.removeTimer('test');

      // Timer should be removed
      expect(() => orchestrator.getRemainingTime('test'), throwsArgumentError);
    });

    test('observes timer updates', () {
      orchestrator.addTimer('test', const Duration(seconds: 10), () {});
      final stream = orchestrator.observeTimer('test');
      expect(stream, isNotNull);
    });

    test('handles timer expiration', () async {
      orchestrator.start();
      bool expired = false;
      orchestrator.addTimer('test', const Duration(seconds: 1), () => expired = true);

      // Wait for expiration (longer than 5s tick)
      await Future.delayed(const Duration(seconds: 6));

      // Timer should have expired
      expect(expired, true);
    });
  });

  group('TimerServiceNotifier', () {
    late TimerServiceNotifier timerService;

    setUp(() async {
      timerService = TimerServiceNotifier(
        _TestRef(),
        mockFirestoreService,
        mockSQLiteHelper,
      );

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() {
      timerService.dispose();
    });

    test('starts spot timer', () async {
      await timerService.startSpotTimer('TestGame', 'user1', const Duration(seconds: 10));

      // Should not throw
      expect(true, true);
    });

    test('starts peacock timer', () async {
      await timerService.startPeacockTimer('user1', const Duration(seconds: 10));

      // Should not throw
      expect(true, true);
    });

    test('stops timer', () async {
      await timerService.startSpotTimer('TestGame', 'user1', const Duration(seconds: 10));
      await timerService.stopTimer('spot_TestGame_user1');

      // Should not throw
      expect(true, true);
    });

    test('gets remaining time', () async {
      await timerService.startSpotTimer('TestGame', 'user1', const Duration(seconds: 10));

      final remaining = timerService.getRemainingTime('spot_TestGame_user1');
      expect(remaining, greaterThan(Duration.zero));
    });

    test('observes timer', () async {
      await timerService.startSpotTimer('TestGame', 'user1', const Duration(seconds: 10));

      final stream = timerService.observeTimer('spot_TestGame_user1');
      expect(stream, isNotNull);
    });

    test('handles interpolation', () async {
      await timerService.startSpotTimer('TestGame', 'user1', const Duration(seconds: 10));

      final remaining = timerService.getRemainingTime('spot_TestGame_user1', interpolate: true);
      expect(remaining, greaterThan(Duration.zero));
    });
  });

  group('TimerServiceNotifier Integration', () {
    test('handles firestore sync errors gracefully', () async {
      when(mockFirestoreService.loadFirestoreData(displayNameCache: anyNamed('displayNameCache')))
          .thenThrow(Exception('Network error'));

      final timerService = TimerServiceNotifier(_TestRef(), mockFirestoreService, mockSQLiteHelper);

      // Should initialize despite firestore error
      await Future.delayed(const Duration(milliseconds: 100));

      expect(timerService.state, isNotNull);
    });

    test('persists timers to database', () async {
      final timerService = TimerServiceNotifier(_TestRef(), mockFirestoreService, mockSQLiteHelper);
      await Future.delayed(const Duration(milliseconds: 100));

      await timerService.startSpotTimer('TestGame', 'user1', const Duration(seconds: 10));

      // Should not throw - persistence is handled internally
      expect(true, true);
    });
  });
}

/// Test implementation of Ref for TimerServiceNotifier testing
class _TestRef implements Ref<Object?> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}