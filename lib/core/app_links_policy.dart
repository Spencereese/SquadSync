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

/// Simulator swallow rules. Google / Supabase auth schemes stay open.
bool shouldSwallowSimulatorAppLink(Uri url) {
  if (isSimulatorAuthScheme(url)) return false;
  final scheme = url.scheme.toLowerCase();
  if (scheme == 'codsquadapp' || scheme == 'com.example.codsquadapp') {
    return true;
  }
  final host = url.host.toLowerCase();
  if (scheme == 'https' || scheme == 'http') {
    if (host == 'lobbiesync.app' || host.endsWith('.lobbiesync.app')) {
      return true;
    }
    if (host.contains('supabase.co')) return true;
  }
  return false;
}

bool isSimulatorAuthScheme(Uri url) {
  final scheme = url.scheme.toLowerCase();
  if (scheme.contains('googleusercontent')) return true;
  final host = url.host.toLowerCase();
  final path = url.path.toLowerCase();
  if (scheme == 'com.example.codsquadapp') {
    return host == 'auth-callback' || path.contains('auth-callback');
  }
  if ((scheme == 'https' || scheme == 'http') && host.contains('supabase.co')) {
    return path.contains('/auth');
  }
  return false;
}

Map<String, String> _platformEnvironment() {
  if (kIsWeb) return const {};
  try {
    return Platform.environment;
  } catch (_) {
    return const {};
  }
}
