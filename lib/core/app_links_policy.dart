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

/// SpringBoard first-open copy. Units mock the tap; they do not talk to
/// SpringBoard. Apple portal / AASA hosting stays a human gate.
const kOpenInCodSquadPrompt = 'Open in Cod Squad?';

final _appLinkControlChars = RegExp(r'[\u0000-\u001F\u007F]');
final _appLinkWhitespace = RegExp(r'\s');

/// Empty, whitespace, control chars, missing scheme, or [Uri.parse] throw.
/// Unknown-but-well-formed URLs are not malformed — they just have no route.
bool isMalformedAppLink(String? link) {
  if (link == null) return true;
  final trimmed = link.trim();
  if (trimmed.isEmpty) return true;
  if (_appLinkControlChars.hasMatch(trimmed)) return true;
  if (_appLinkWhitespace.hasMatch(trimmed)) return true;
  final Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return true;
  }
  if (!uri.hasScheme || uri.scheme.trim().isEmpty) return true;
  final scheme = uri.scheme.toLowerCase();
  if (scheme.contains('googleusercontent')) return false;
  const known = {
    'codsquadapp',
    'https',
    'http',
    'com.example.codsquadapp',
  };
  if (!known.contains(scheme)) return true;
  if ((scheme == 'https' || scheme == 'http') && uri.host.trim().isEmpty) {
    return true;
  }
  return false;
}

Uri? tryParseAppLinkUri(String? link) {
  if (isMalformedAppLink(link)) return null;
  try {
    return Uri.parse(link!.trim());
  } catch (_) {
    return null;
  }
}

bool isLobbyUniversalLinkHost(String? host) {
  final name = host?.trim().toLowerCase() ?? '';
  if (name.isEmpty) return false;
  return name == 'codsquad.app' || name == 'www.codsquad.app';
}

/// AASA-claimed Universal Link: `https://codsquad.app/l/<id>` (and www / http).
/// Other https paths may still parse in Dart; they are not associated-domains
/// `/l/*` deliveries.
bool isLobbyUniversalLinkUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return false;
  if (!isLobbyUniversalLinkHost(uri.host)) return false;
  final segments =
      uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  return segments.isNotEmpty && segments.first.toLowerCase() == 'l';
}

bool isLobbyUniversalLink(String? link) {
  final uri = tryParseAppLinkUri(link);
  if (uri == null) return false;
  return isLobbyUniversalLinkUri(uri);
}

/// Mocked tap on the Open-in sheet or Associated Domains delivery gate.
enum AppLinkAcceptDecision {
  /// Sheet is showing; Dart has not received the URL yet.
  pending,

  /// Human / mock Accept. URL may proceed to the existing parser.
  accept,

  /// Human / mock Cancel. No pending location.
  cancel,
}

enum AppLinkAcceptKind {
  customScheme,
  universalLink,
  swallowed,
  malformed,
  unknown,
}

/// Mock of SpringBoard "Open in Cod Squad?" and Associated Domains delivery.
///
/// Units inject Accept / Cancel. Does not talk to SpringBoard, DNS, or the
/// Apple portal. Default associated-domains decision is Cancel (AASA hosting
/// stays a human gate).
class AppLinkAcceptGate {
  AppLinkAcceptGate({
    AppLinkAcceptDecision customSchemeDecision = AppLinkAcceptDecision.pending,
    AppLinkAcceptDecision associatedDomainsDecision =
        AppLinkAcceptDecision.cancel,
    bool customSchemeAcceptedThisInstall = false,
  })  : _customSchemeDecision = customSchemeDecision,
        _associatedDomainsDecision = associatedDomainsDecision,
        _customSchemeAcceptedThisInstall = customSchemeAcceptedThisInstall ||
            customSchemeDecision == AppLinkAcceptDecision.accept;

  /// Current tree: custom-scheme works after the one-time Open-in tap;
  /// Associated Domains / AASA is still blocked.
  factory AppLinkAcceptGate.portalBlocked() => AppLinkAcceptGate(
        customSchemeDecision: AppLinkAcceptDecision.accept,
        associatedDomainsDecision: AppLinkAcceptDecision.cancel,
      );

  /// Device after Spencer portal + DNS and the Open-in Accept.
  factory AppLinkAcceptGate.deviceReady() => AppLinkAcceptGate(
        customSchemeDecision: AppLinkAcceptDecision.accept,
        associatedDomainsDecision: AppLinkAcceptDecision.accept,
      );

  AppLinkAcceptDecision _customSchemeDecision;
  AppLinkAcceptDecision _associatedDomainsDecision;
  bool _customSchemeAcceptedThisInstall;

  AppLinkAcceptDecision get customSchemeDecision => _customSchemeDecision;
  AppLinkAcceptDecision get associatedDomainsDecision =>
      _associatedDomainsDecision;
  bool get customSchemeAcceptedThisInstall => _customSchemeAcceptedThisInstall;

  /// Record the mocked SpringBoard tap. Accept sticks for this install.
  void answerCustomSchemePrompt(AppLinkAcceptDecision decision) {
    _customSchemeDecision = decision;
    if (decision == AppLinkAcceptDecision.accept) {
      _customSchemeAcceptedThisInstall = true;
    }
  }

  /// Mock of Spencer's Associated Domains / AASA portal result.
  void mockAssociatedDomainsPortal(AppLinkAcceptDecision decision) {
    _associatedDomainsDecision = decision;
  }

  bool presentsCustomSchemePrompt(Uri url) {
    if (!isProductCustomSchemeAppLink(url)) return false;
    if (_customSchemeAcceptedThisInstall) return false;
    return _customSchemeDecision == AppLinkAcceptDecision.pending;
  }

  /// Whether iOS would hand [link] to Dart. Parser is separate.
  bool delivers(String? link, {bool? isIosSimulator}) {
    if (isMalformedAppLink(link)) return false;
    final uri = tryParseAppLinkUri(link);
    if (uri == null) return false;
    final sim = isIosSimulator ?? detectIosSimulator();
    if (sim && shouldSwallowSimulatorAppLink(uri)) return false;
    if (isProductCustomSchemeAppLink(uri)) {
      if (_customSchemeAcceptedThisInstall) return true;
      return _customSchemeDecision == AppLinkAcceptDecision.accept;
    }
    if (isLobbyUniversalLinkUri(uri)) {
      if (sim) return false;
      return _associatedDomainsDecision == AppLinkAcceptDecision.accept;
    }
    return false;
  }
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
