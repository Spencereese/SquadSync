import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const iosSimulatorChannelName = 'com.example.codSquadApp/runtime';

bool? _channelSaysSimulator;

@visibleForTesting
void debugSetIosSimulatorChannelValue(bool? value) {
  _channelSaysSimulator = value;
}

/// Whether to consume `getInitialLink()` at launch.
/// iOS Simulator skips the leftover launch URL that shows
/// "Open in Cod Squad?" over ChatScreen. Physical devices keep it.
bool shouldConsumeLaunchAppLink({bool? isIosSimulator}) {
  return !(isIosSimulator ?? detectIosSimulator());
}

/// Cold/warm AppLinks after launch. Always subscribe — do not black out Dart.
bool shouldSubscribeUriLinkStream() => true;

/// Simulator skips only the initial launch link; [uriLinkStream] stays on.
({bool consumeInitialLink, bool subscribeUriLinkStream}) planAppLinkListen({
  bool? isIosSimulator,
}) {
  return (
    consumeInitialLink:
        shouldConsumeLaunchAppLink(isIosSimulator: isIosSimulator),
    subscribeUriLinkStream: shouldSubscribeUriLinkStream(),
  );
}

/// SIMULATOR_* keys on the Dart isolate. Logged only — never used to detect.
bool simulatorEnvKeysPresent([Map<String, String>? environment]) {
  final env = environment ?? _platformEnvironment();
  return env.containsKey('SIMULATOR_DEVICE_NAME') ||
      env.containsKey('SIMULATOR_UDID') ||
      env.containsKey('SIMULATOR_ROOT');
}

/// Simulator bit from AppDelegate `#if targetEnvironment(simulator)`.
/// Does not trust [environment] / SIMULATOR_* keys.
bool detectIosSimulator({
  bool? channelSaysSimulator,
  Map<String, String>? environment,
}) {
  final fromChannel = channelSaysSimulator ?? _channelSaysSimulator;
  return fromChannel ?? false;
}

Future<bool> loadIosSimulatorFromChannel({MethodChannel? channel}) async {
  final ch = channel ?? const MethodChannel(iosSimulatorChannelName);
  try {
    final value = await ch.invokeMethod<bool>('isIosSimulator');
    _channelSaysSimulator = value ?? false;
  } catch (e) {
    debugPrint('isIosSimulator channel failed: $e');
    _channelSaysSimulator = false;
  }
  return _channelSaysSimulator!;
}

Map<String, String> _platformEnvironment() {
  if (kIsWeb) return const {};
  try {
    return Platform.environment;
  } catch (_) {
    return const {};
  }
}
