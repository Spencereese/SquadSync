import 'dart:async';

import 'package:squadsync/features/push/domain/squad_push.dart';

/// Whether this install can receive squad pushes.
class PushAvailability {
  const PushAvailability.off() : token = null, platform = null;

  const PushAvailability.on({required this.token, required this.platform});

  final String? token;
  final String? platform;

  bool get on => token != null && token!.isNotEmpty && platform != null;
}

/// The phone's push client. The default install has no SDK and stays off.
abstract class PushNotifications {
  Future<PushAvailability> availability();

  Stream<SquadPush> get taps;

  /// The message that launched the process, once. Later reads are null.
  SquadPush? consumeLaunch();
}

/// No Firebase and no APNs token. The home screen says notifications are off.
class UnconfiguredPushNotifications implements PushNotifications {
  const UnconfiguredPushNotifications();

  @override
  Future<PushAvailability> availability() async => const PushAvailability.off();

  @override
  Stream<SquadPush> get taps => const Stream.empty();

  @override
  SquadPush? consumeLaunch() => null;
}

/// Test double. [enabled] with a token is the only path that registers.
class FakePushNotifications implements PushNotifications {
  FakePushNotifications({
    this.launch,
    this.availabilityResult = const PushAvailability.off(),
  });

  SquadPush? launch;
  PushAvailability availabilityResult;
  final _taps = StreamController<SquadPush>.broadcast();

  void deliver(SquadPush push) {
    if (!_taps.isClosed) _taps.add(push);
  }

  @override
  Future<PushAvailability> availability() async => availabilityResult;

  @override
  Stream<SquadPush> get taps => _taps.stream;

  @override
  SquadPush? consumeLaunch() {
    final pending = launch;
    launch = null;
    return pending;
  }
}
