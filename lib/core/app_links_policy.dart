import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const iosSimulatorChannelName = 'com.example.codSquadApp/runtime';

bool? _channelSaysSimulator;
String? _lastSimSceneHostedLine;

@visibleForTesting
void debugSetIosSimulatorChannelValue(bool? value) {
  _channelSaysSimulator = value;
}

@visibleForTesting
void debugResetSimSceneHostedLog() {
  _lastSimSceneHostedLine = null;
}

/// Deduped Flutter log so `flutter run` stdout sees the native host line.
void logSimSceneHostedLine(
  String? line, {
  void Function(String message)? log,
}) {
  final text = line?.trim() ?? '';
  if (text.isEmpty) return;
  if (text == _lastSimSceneHostedLine) return;
  _lastSimSceneHostedLine = text;
  (log ?? debugPrint)(text);
}

/// Whether to call `getInitialLink()` at launch.
///
/// Always read it. Simulator leftover https / bundle-id URLs are dropped
/// later by [shouldSwallowSimulatorAppLink] on the live AppLinks path.
/// Skipping the call entirely dropped `codsquadapp://lobby/<id>` before
/// [locationForDeepLink] ran (cold `simctl openurl` stayed on splash).
bool shouldConsumeLaunchAppLink({bool? isIosSimulator, Uri? url}) {
  if (url != null && (isIosSimulator ?? detectIosSimulator())) {
    return !shouldSwallowSimulatorAppLink(url);
  }
  return true;
}

/// Cold/warm AppLinks after launch. Always subscribe — do not black out Dart.
bool shouldSubscribeUriLinkStream() => true;

/// Always read getInitialLink and subscribe. Simulator leftover https is
/// filtered per-URL by [shouldSwallowSimulatorAppLink] on the live path.
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
  await loadSimSceneHostedFromChannel(channel: ch);
  return _channelSaysSimulator!;
}

/// Native host line after Dart attach. Complements [bindRuntimeHostedLogHandler].
Future<void> loadSimSceneHostedFromChannel({MethodChannel? channel}) async {
  final ch = channel ?? const MethodChannel(iosSimulatorChannelName);
  try {
    final value = await ch.invokeMethod<String>('getSimSceneHosted');
    logSimSceneHostedLine(value);
  } catch (e) {
    debugPrint('getSimSceneHosted channel failed: $e');
  }
}

/// Native → Dart `simSceneHosted` so flutter run captures the host line.
void bindRuntimeHostedLogHandler({MethodChannel? channel}) {
  final ch = channel ?? const MethodChannel(iosSimulatorChannelName);
  ch.setMethodCallHandler((call) async {
    if (call.method == 'simSceneHosted') {
      logSimSceneHostedLine(call.arguments?.toString());
    }
    return null;
  });
}

/// Product custom scheme registered for simctl / share / lobby links.
/// Must reach Dart — do not treat as leftover Launch Services UL.
bool isProductCustomSchemeAppLink(Uri url) {
  return url.scheme.toLowerCase() == 'codsquadapp';
}

/// Simulator swallow rules. Google / Supabase auth schemes stay open.
/// `codsquadapp://` product URLs (lobby / squad / peacock / chat / join)
/// are not swallowed so `simctl openurl` can route. Leftover https
/// Universal Links and the bundle-id scheme (except auth) still drop.
bool shouldSwallowSimulatorAppLink(Uri url) {
  if (isSimulatorAuthScheme(url)) return false;
  if (isProductCustomSchemeAppLink(url)) return false;
  final scheme = url.scheme.toLowerCase();
  if (scheme == 'com.example.codsquadapp') {
    return true;
  }
  final host = url.host.toLowerCase();
  if (scheme == 'https' || scheme == 'http') {
    if (host == 'lobbiesync.app' || host.endsWith('.lobbiesync.app')) {
      return true;
    }
    if (host == 'codsquad.app' || host.endsWith('.codsquad.app')) {
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
