import 'package:flutter_test/flutter_test.dart';

import 'package:squad_sync/services/timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimerService timerService;

  setUp(() {
    timerService = TimerService();
  });

  group('TimerService', () {
    test(
        'starting a timer and verifying remaining time decreases correctly over simulated ticks',
        () async {
      const key = 'test_timer_1';
      const duration = Duration(seconds: 2);

      timerService.startTimer(key, duration, () {});

      // Initial remaining time
      expect(
          (timerService.getRemainingTime(key) - duration).inMilliseconds.abs(),
          lessThan(100));

      await Future.delayed(const Duration(seconds: 1));
      expect(
          (timerService.getRemainingTime(key) - const Duration(seconds: 1))
              .inMilliseconds
              .abs(),
          lessThan(100));
    });

    test('expiration callback fires after duration', () async {
      const key = 'test_timer_2';
      const duration = Duration(seconds: 6);
      bool callbackFired = false;

      timerService.startTimer(key, duration, () {
        callbackFired = true;
      });

      await Future.delayed(const Duration(seconds: 11));
      expect(callbackFired, true);
    });

    test('stopping a timer mid-way', () async {
      const key = 'test_timer_3';
      const duration = Duration(seconds: 2);

      timerService.startTimer(key, duration, () {});

      await Future.delayed(const Duration(seconds: 1));
      expect(
          (timerService.getRemainingTime(key) - const Duration(seconds: 1))
              .inMilliseconds
              .abs(),
          lessThan(100));

      // Stop the timer
      timerService.stopTimer(key);

      // After stop, should throw
      expect(() => timerService.getRemainingTime(key),
          throwsA(isA<ArgumentError>()));
    });

    test('getting remaining time for non-existent key throws error', () {
      expect(() => timerService.getRemainingTime('non_existent'),
          throwsA(isA<ArgumentError>()));
    });

    test('stream emits only on changes', () async {
      const key = 'test_timer_4';
      const duration = Duration(seconds: 10);
      final emissions = <Duration>[];

      timerService.startTimer(key, duration, () {});

      final stream = timerService.observeTimer(key);

      final subscription = stream.listen((duration) {
        emissions.add(duration);
      });

      // Wait for next tick
      await Future.delayed(const Duration(seconds: 5));
      expect(emissions.length, 1);
      expect((emissions[0] - const Duration(seconds: 5)).inSeconds.abs(),
          lessThan(2));

      // Wait for another tick
      await Future.delayed(const Duration(seconds: 5));
      expect(emissions.length, 2);
      expect(emissions[1], Duration.zero);

      subscription.cancel();
    });
  });
}
