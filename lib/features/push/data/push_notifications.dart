import 'dart:async';

import 'package:squadsync/features/push/domain/squad_push.dart';

/// Whether this install can receive squad pushes.
class PushAvailability {
  const PushAvailability.off({this.setupMissing = false})
    : token = null,
      platform = null;

  const PushAvailability.on({required this.token, required this.platform})
    : setupMissing = false;

  final String? token;
  final String? platform;

  /// Firebase has no config file on this build. Distinct from a denied prompt.
  final bool setupMissing;

  bool get on => token != null && token!.isNotEmpty && platform != null;
}

/// The phone's push client. The default install has no SDK and stays off.
abstract class PushNotifications {
  Future<PushAvailability> availability();

  Stream<SquadPush> get taps;

  /// A new FCM token. Empty when this install has no push SDK.
  Stream<PushAvailability> get tokenChanges;

  /// The message that launched the process, once. Later reads are null.
  SquadPush? consumeLaunch();

  /// Drops the token at the push service. The row is removed separately.
  Future<void> deleteLocalToken();
}

/// No Firebase config, or no token yet. The home screen says notifications are off.
class UnconfiguredPushNotifications implements PushNotifications {
  const UnconfiguredPushNotifications({this.setupMissing = false});

  final bool setupMissing;

  @override
  Future<PushAvailability> availability() async {
    return PushAvailability.off(setupMissing: setupMissing);
  }

  @override
  Stream<SquadPush> get taps => const Stream.empty();

  @override
  Stream<PushAvailability> get tokenChanges => const Stream.empty();

  @override
  SquadPush? consumeLaunch() => null;

  @override
  Future<void> deleteLocalToken() async {}
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
  final _tokens = StreamController<PushAvailability>.broadcast();
  var deletedLocal = false;

  void deliver(SquadPush push) {
    if (!_taps.isClosed) _taps.add(push);
  }

  void refreshToken(PushAvailability next) {
    availabilityResult = next;
    if (!_tokens.isClosed) _tokens.add(next);
  }

  @override
  Future<PushAvailability> availability() async => availabilityResult;

  @override
  Stream<SquadPush> get taps => _taps.stream;

  @override
  Stream<PushAvailability> get tokenChanges => _tokens.stream;

  @override
  Future<void> deleteLocalToken() async {
    deletedLocal = true;
    availabilityResult = const PushAvailability.off();
  }

  @override
  SquadPush? consumeLaunch() {
    final pending = launch;
    launch = null;
    return pending;
  }
}
