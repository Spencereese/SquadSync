import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'app_links_policy.dart';
import 'lobby_chat_bind.dart';
import 'notification_routes.dart';

/// Custom scheme registered on device [Info.plist] and simulator
/// [Info.simulator.plist]. Unit tests assert the plist file; they do not
/// talk to SpringBoard ("Open in Cod Squad?" remains a human gate).
const kSimulatorDeepLinkScheme = 'codsquadapp';

/// Auth-callback scheme. Bundle ID stays `com.example.codSquadApp`.
const kSimulatorAuthCallbackScheme = 'com.example.codSquadApp';

const kSimulatorRegisteredUrlSchemes = [
  kSimulatorDeepLinkScheme,
  kSimulatorAuthCallbackScheme,
];

/// HTTPS Universal Link host. [locationForDeepLink] maps
/// `https://codsquad.app/l/<id>` to the same `/squad?lobby_id=` path as
/// `codsquadapp://lobby/<id>`. Device entitlements claim applinks; AASA
/// hosting / Apple portal still need Spencer.
const kLobbyUniversalLinkHost = 'codsquad.app';

/// URL the chat peacock card opens. [locationForDeepLink] is the parse.
/// [spotIndex] is the offered seat (0-based) — same `spot_index` query
/// as notification `peacock_assigned` payloads.
String peacockCardDeepLink({
  String? lobbyId,
  String? gameName,
  int? spotIndex,
}) {
  return Uri(
    scheme: kSimulatorDeepLinkScheme,
    host: 'peacock',
    queryParameters: {
      if (_nonEmpty(lobbyId) != null) 'lobby_id': lobbyId!.trim(),
      if (_nonEmpty(gameName) != null) 'game_name': gameName!.trim(),
      if (spotIndex != null && spotIndex >= 0) 'spot_index': '$spotIndex',
    },
  ).toString();
}

/// Notification payload the chat peacock card tap shares with
/// `peacock_assigned` taps (same [NotificationRoutes] table).
Map<String, dynamic> peacockCardNotificationPayload({
  String? lobbyId,
  String? gameName,
  int? spotIndex,
}) {
  return {
    'type': 'peacock_assigned',
    if (_nonEmpty(lobbyId) != null) 'lobby_id': lobbyId!.trim(),
    if (_nonEmpty(gameName) != null) 'game_name': gameName!.trim(),
    if (spotIndex != null && spotIndex >= 0) 'spot_index': spotIndex,
  };
}

/// Chat peacock card tap. Same parse + [NotificationRoutes.go] as
/// notification taps and App Links. [spotIndex] highlights the offered
/// spot on `/squad`. Offline does not navigate — Retry is the card
/// action, not a second presenter.
void openPeacockCard({
  String? lobbyId,
  String? gameName,
  int? spotIndex,
  void Function(String location)? go,
  bool isOffline = false,
}) {
  if (isOffline) return;
  final location = locationForDeepLink(
    peacockCardDeepLink(
      lobbyId: lobbyId,
      gameName: gameName,
      spotIndex: spotIndex,
    ),
  );
  if (location == null) return;
  (go ?? NotificationRoutes.go)?.call(location);
}

/// Share/copy URI for this lobby. [locationForDeepLink] is the parse.
String lobbyShareDeepLink({required String lobbyId}) {
  final id = lobbyId.trim();
  if (id.isEmpty) {
    return Uri(scheme: kSimulatorDeepLinkScheme, host: 'lobby').toString();
  }
  return Uri(
    scheme: kSimulatorDeepLinkScheme,
    host: 'lobby',
    pathSegments: [id],
  ).toString();
}

/// HTTPS Universal Link fallback for this lobby. Same parse as
/// [lobbyShareDeepLink] via [locationForDeepLink].
String lobbyShareHttpsLink({required String lobbyId}) {
  final id = lobbyId.trim();
  if (id.isEmpty) {
    return Uri(
      scheme: 'https',
      host: kLobbyUniversalLinkHost,
      path: '/l',
    ).toString();
  }
  return Uri(
    scheme: 'https',
    host: kLobbyUniversalLinkHost,
    pathSegments: ['l', id],
  ).toString();
}

/// Share-sheet text: app scheme plus https Universal Link fallback.
/// Empty / whitespace lobby id does not invent a link.
String lobbySharePayload({required String lobbyId}) {
  final id = lobbyId.trim();
  if (id.isEmpty) return '';
  return '${lobbyShareDeepLink(lobbyId: id)}\n'
      '${lobbyShareHttpsLink(lobbyId: id)}';
}

bool lobbySharePayloadIsEmpty(String? payload) {
  return payload == null || payload.trim().isEmpty;
}

/// Outcome of [shareLobbyLink]. Success copies the payload; empty lobby
/// id / empty payload does not invent a link; clipboard failure does not
/// claim copied; share-sheet cancel is silent; offline does not copy.
enum LobbyShareOutcome {
  success,
  empty,
  clipboardFailed,
  cancelled,
  offline,
}

const kLobbyShareCopiedCopy = 'Lobby link copied';
const kLobbyShareEmptyCopy = 'No lobby selected';
const kLobbyShareClipboardFailedCopy = 'Could not copy lobby link';
const kLobbyShareOfflineCopy = "You're offline";

/// Share sheet dismissed. Clipboard already holds the payload.
class LobbyShareSheetCancelled implements Exception {
  const LobbyShareSheetCancelled();

  @override
  String toString() => 'sheet dismissed';
}

class LobbyShareResult {
  const LobbyShareResult.success(this.payload)
      : outcome = LobbyShareOutcome.success,
        error = null;

  const LobbyShareResult.empty()
      : outcome = LobbyShareOutcome.empty,
        payload = null,
        error = null;

  const LobbyShareResult.clipboardFailed({this.error, this.payload})
      : outcome = LobbyShareOutcome.clipboardFailed;

  const LobbyShareResult.cancelled({this.payload})
      : outcome = LobbyShareOutcome.cancelled,
        error = null;

  const LobbyShareResult.offline({this.error, this.payload})
      : outcome = LobbyShareOutcome.offline;

  final LobbyShareOutcome outcome;
  final String? payload;
  final Object? error;

  bool get isSuccess => outcome == LobbyShareOutcome.success;
  bool get isEmpty => outcome == LobbyShareOutcome.empty;
  bool get isClipboardFailed => outcome == LobbyShareOutcome.clipboardFailed;
  bool get isCancelled => outcome == LobbyShareOutcome.cancelled;
  bool get isOffline => outcome == LobbyShareOutcome.offline;
}

Key lobbyShareFeedbackKey(LobbyShareOutcome outcome) {
  switch (outcome) {
    case LobbyShareOutcome.success:
      return const Key('lobby-share-copied');
    case LobbyShareOutcome.empty:
      return const Key('lobby-share-empty');
    case LobbyShareOutcome.clipboardFailed:
      return const Key('lobby-share-clipboard-failed');
    case LobbyShareOutcome.cancelled:
      return const Key('lobby-share-cancelled');
    case LobbyShareOutcome.offline:
      return const Key('lobby-share-offline');
  }
}

String lobbyShareErrorDetail(Object? error) {
  if (error == null) return '';
  var text = error.toString().trim();
  if (text.isEmpty) return '';
  const prefix = 'Exception:';
  if (text.startsWith(prefix)) {
    text = text.substring(prefix.length).trim();
  }
  return text;
}

/// Share-sheet dismiss / cancel. [ShareResultStatus.dismissed] or a
/// cancel/dismissed error — not a copy failure.
bool lobbyShareIsCancelled(Object? value) {
  if (value is LobbyShareSheetCancelled) return true;
  if (value is ShareResult) {
    return value.status == ShareResultStatus.dismissed;
  }
  if (value == null) return false;
  final text = value.toString().toLowerCase();
  return text.contains('cancel') || text.contains('dismiss');
}

/// Socket / network / offline errors on copy or share.
bool lobbyShareIsOfflineError(Object? error) {
  if (error == null) return false;
  final text = error.toString().toLowerCase();
  return text.contains('socket') ||
      text.contains('offline') ||
      text.contains('network') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('clientexception');
}

/// Map a share-sheet [ShareResult] (or thrown cancel) to an outcome.
/// Dismissed is cancel; success / unavailable stay success (copy holds).
LobbyShareOutcome lobbyShareSheetOutcome(Object? result) {
  if (lobbyShareIsCancelled(result)) return LobbyShareOutcome.cancelled;
  return LobbyShareOutcome.success;
}

String lobbyShareMessage(LobbyShareResult result) {
  switch (result.outcome) {
    case LobbyShareOutcome.success:
      return kLobbyShareCopiedCopy;
    case LobbyShareOutcome.empty:
      return kLobbyShareEmptyCopy;
    case LobbyShareOutcome.clipboardFailed:
      final detail = lobbyShareErrorDetail(result.error);
      if (detail.isEmpty) return kLobbyShareClipboardFailedCopy;
      return '$kLobbyShareClipboardFailedCopy: $detail';
    case LobbyShareOutcome.cancelled:
      return '';
    case LobbyShareOutcome.offline:
      final detail = lobbyShareErrorDetail(result.error);
      if (detail.isEmpty) return kLobbyShareOfflineCopy;
      return '$kLobbyShareOfflineCopy: $detail';
  }
}

/// SnackBar for [shareLobbyLink] — success toast, empty, clipboard fail,
/// offline. Cancel is silent ([presentLobbyShare] skips it).
SnackBar lobbyShareSnackBar(LobbyShareResult result) {
  return SnackBar(
    content: Text(
      lobbyShareMessage(result),
      key: lobbyShareFeedbackKey(result.outcome),
    ),
    behavior: SnackBarBehavior.floating,
  );
}

void presentLobbyShare(BuildContext context, LobbyShareResult result) {
  if (!context.mounted) return;
  if (result.outcome == LobbyShareOutcome.cancelled) return;
  ScaffoldMessenger.of(context).showSnackBar(lobbyShareSnackBar(result));
}

/// Copy [lobbySharePayload] then open the system share sheet.
/// Live path: lobby header / Tonight Invite. Tests inject [copy] / [share].
/// Empty / whitespace lobby id or empty payload is
/// [LobbyShareOutcome.empty] — no copy, no sheet. Offline does not copy.
/// Share-sheet cancel is [LobbyShareOutcome.cancelled] after copy.
Future<LobbyShareResult> shareLobbyLink({
  String? lobbyId,
  String? payload,
  Future<void> Function(String link)? copy,
  Future<void> Function(String link)? share,
  bool isOffline = false,
}) async {
  final id = lobbyId?.trim() ?? '';
  final text = payload ?? (id.isEmpty ? '' : lobbySharePayload(lobbyId: id));
  if (lobbySharePayloadIsEmpty(text)) {
    return const LobbyShareResult.empty();
  }
  if (isOffline) {
    return LobbyShareResult.offline(payload: text);
  }
  try {
    await (copy ?? _copyLobbyLinkToClipboard)(text);
  } catch (e) {
    if (lobbyShareIsOfflineError(e)) {
      return LobbyShareResult.offline(error: e, payload: text);
    }
    return LobbyShareResult.clipboardFailed(error: e, payload: text);
  }
  try {
    await (share ?? _shareLobbyLinkSheet)(text);
  } catch (e) {
    if (lobbyShareIsOfflineError(e)) {
      return LobbyShareResult.offline(error: e, payload: text);
    }
    if (lobbyShareIsCancelled(e)) {
      return LobbyShareResult.cancelled(payload: text);
    }
    // Clipboard already holds [text].
  }
  return LobbyShareResult.success(text);
}

Future<void> _copyLobbyLinkToClipboard(String payload) {
  return Clipboard.setData(ClipboardData(text: payload));
}

Future<void> _shareLobbyLinkSheet(String payload) async {
  final result = await SharePlus.instance.share(ShareParams(text: payload));
  if (result.status == ShareResultStatus.dismissed) {
    throw const LobbyShareSheetCancelled();
  }
}

/// Live AppLinks gate used by [main] / [DeepLinkRouter.handleDeepLink].
/// Simulator leftover https UL is dropped; product `codsquadapp://`
/// URLs still map through [locationForDeepLink] (unknown lobby ids
/// included).
String? locationForLiveAppLink(
  String link, {
  bool? isIosSimulator,
}) {
  final trimmed = link.trim();
  if (trimmed.isEmpty) return null;
  if (isMalformedAppLink(trimmed)) return null;
  Uri? uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return null;
  }
  if ((isIosSimulator ?? detectIosSimulator()) &&
      shouldSwallowSimulatorAppLink(uri)) {
    return null;
  }
  return locationForDeepLink(trimmed);
}

/// Live-path helper: resolve [link], log, and dismiss splash when a
/// product route is consumed. Call from AppLinks listen — not a scaffold.
String? prepareLiveAppLink(
  String link, {
  bool? isIosSimulator,
  void Function()? dismissSplash,
  void Function(String message)? log,
}) {
  final logger = log ?? debugPrint;
  final location = locationForLiveAppLink(
    link,
    isIosSimulator: isIosSimulator,
  );
  if (location == null) {
    logger('AppLinks: drop $link');
    return null;
  }
  logger('AppLinks: $link -> $location');
  dismissSplash?.call();
  return location;
}

/// AASA `/l/*` Universal Link after delivery. Malformed and non-`/l/`
/// https URLs return null. [acceptGate] mocks Associated Domains Accept
/// without portal / DNS work; omit it to parse as if already delivered.
String? locationForUniversalLink(
  String? link, {
  bool? isIosSimulator,
  AppLinkAcceptGate? acceptGate,
}) {
  if (link == null || isMalformedAppLink(link)) return null;
  final uri = tryParseAppLinkUri(link);
  if (uri == null || !isLobbyUniversalLinkUri(uri)) return null;
  if (acceptGate != null &&
      !acceptGate.delivers(link, isIosSimulator: isIosSimulator)) {
    return null;
  }
  return locationForLiveAppLink(link, isIosSimulator: isIosSimulator);
}

/// SpringBoard / Associated Domains Accept-gate probe. Location is the
/// existing [locationForDeepLink] table when the mock delivers.
class AppLinkAcceptOutcome {
  const AppLinkAcceptOutcome({
    required this.kind,
    required this.decision,
    required this.presentedPrompt,
    this.location,
    this.prompt,
  });

  final AppLinkAcceptKind kind;
  final AppLinkAcceptDecision decision;
  final bool presentedPrompt;
  final String? location;
  final String? prompt;

  bool get delivers => location != null;
}

AppLinkAcceptOutcome resolveAppLinkAccept({
  required String? link,
  required AppLinkAcceptGate gate,
  bool? isIosSimulator,
}) {
  if (isMalformedAppLink(link)) {
    return const AppLinkAcceptOutcome(
      kind: AppLinkAcceptKind.malformed,
      decision: AppLinkAcceptDecision.cancel,
      presentedPrompt: false,
    );
  }
  final trimmed = link!.trim();
  final uri = tryParseAppLinkUri(trimmed);
  if (uri == null) {
    return const AppLinkAcceptOutcome(
      kind: AppLinkAcceptKind.malformed,
      decision: AppLinkAcceptDecision.cancel,
      presentedPrompt: false,
    );
  }
  final sim = isIosSimulator ?? detectIosSimulator();
  if (sim && shouldSwallowSimulatorAppLink(uri)) {
    return const AppLinkAcceptOutcome(
      kind: AppLinkAcceptKind.swallowed,
      decision: AppLinkAcceptDecision.cancel,
      presentedPrompt: false,
    );
  }
  if (isProductCustomSchemeAppLink(uri)) {
    final presented = gate.presentsCustomSchemePrompt(uri);
    if (presented) {
      return const AppLinkAcceptOutcome(
        kind: AppLinkAcceptKind.customScheme,
        decision: AppLinkAcceptDecision.pending,
        presentedPrompt: true,
        prompt: kOpenInCodSquadPrompt,
      );
    }
    if (!gate.delivers(trimmed, isIosSimulator: sim)) {
      return const AppLinkAcceptOutcome(
        kind: AppLinkAcceptKind.customScheme,
        decision: AppLinkAcceptDecision.cancel,
        presentedPrompt: false,
      );
    }
    return AppLinkAcceptOutcome(
      kind: AppLinkAcceptKind.customScheme,
      decision: AppLinkAcceptDecision.accept,
      presentedPrompt: false,
      location: locationForLiveAppLink(trimmed, isIosSimulator: sim),
    );
  }
  if (isLobbyUniversalLinkUri(uri)) {
    if (!gate.delivers(trimmed, isIosSimulator: sim)) {
      return AppLinkAcceptOutcome(
        kind: AppLinkAcceptKind.universalLink,
        decision: gate.associatedDomainsDecision,
        presentedPrompt: false,
      );
    }
    return AppLinkAcceptOutcome(
      kind: AppLinkAcceptKind.universalLink,
      decision: AppLinkAcceptDecision.accept,
      presentedPrompt: false,
      location: locationForLiveAppLink(trimmed, isIosSimulator: sim),
    );
  }
  return const AppLinkAcceptOutcome(
    kind: AppLinkAcceptKind.unknown,
    decision: AppLinkAcceptDecision.cancel,
    presentedPrompt: false,
  );
}

/// Pure mapping from an App Link / custom-scheme URI to a go_router
/// location. Returns null for auth callbacks and unknown URIs.
///
/// Peacock card, notification, `lfg_matched` / `lfg_alert` /
/// `availability_ping` / peacock / lobby URLs all go through here then
/// [NotificationRoutes.locationFor].
String? locationForDeepLink(String link) {
  final trimmed = link.trim();
  if (trimmed.isEmpty) return null;
  if (isMalformedAppLink(trimmed)) return null;
  try {
    return locationForDeepLinkUri(Uri.parse(trimmed));
  } catch (_) {
    return null;
  }
}

String? locationForDeepLinkUri(Uri uri) {
  if (isSimulatorAuthScheme(uri) &&
      (uri.host.toLowerCase() == 'auth-callback' ||
          uri.path.toLowerCase().contains('auth-callback'))) {
    return null;
  }

  final asString = uri.toString();
  final chatId = chatIdFromAppLink(asString);
  if (chatId != null) return '/chat/$chatId';
  if (isChatListAppLink(asString)) return '/chat';

  final host = uri.host.toLowerCase();
  final segments =
      uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  final query = uri.queryParameters;

  final joinCode = _joinCode(host: host, segments: segments, query: query);
  if (joinCode != null) {
    return '/join/${Uri.encodeComponent(joinCode)}';
  }

  final queryType = (query['type'] ?? '').toLowerCase();
  final queryScreen = (query['screen'] ?? '').toLowerCase();
  final lobbyId = _nonEmpty(query['lobby_id']) ??
      _nonEmpty(query['lobbyId']) ??
      _nonEmpty(query['lobby']) ??
      _lobbyIdFromPath(host: host, segments: segments);
  var gameName = _nonEmpty(query['game_name']) ?? _nonEmpty(query['gameName']);
  gameName ??= _gameNameFromPath(host: host, segments: segments);

  final mappedType = _mappedType(
    queryType: queryType,
    host: host,
    segments: segments,
  );
  var screen = queryScreen;
  if (screen.isEmpty) {
    if (_matchesName(host, segments, 'lobby') ||
        _isShortLobbyLink(host: host, segments: segments)) {
      screen = 'lobby';
    } else if (_matchesName(host, segments, 'squad')) {
      screen = 'squad';
    } else if (_matchesName(host, segments, 'stats')) {
      screen = 'stats';
    }
  }

  if (mappedType == null && screen.isEmpty) {
    return null;
  }

  return NotificationRoutes.locationFor({
    ...query,
    if (mappedType != null) 'type': mappedType,
    if (screen.isNotEmpty) 'screen': screen,
    if (lobbyId != null) 'lobby_id': lobbyId,
    if (gameName != null) 'game_name': gameName,
  });
}

String? _mappedType({
  required String queryType,
  required String host,
  required List<String> segments,
}) {
  if (queryType.isNotEmpty) {
    return queryType == 'peacock' ? 'peacock_assigned' : queryType;
  }
  if (_matchesName(host, segments, 'lfg_matched')) return 'lfg_matched';
  if (_matchesName(host, segments, 'lfg_alert')) return 'lfg_alert';
  if (_matchesName(host, segments, 'availability_ping')) {
    return 'availability_ping';
  }
  if (_matchesName(host, segments, 'lobby_locked')) {
    return 'lobby_locked';
  }
  if (_matchesName(host, segments, 'peacock')) return 'peacock_assigned';
  if (_matchesName(host, segments, 'stats')) return 'stats';
  return null;
}

bool _matchesName(String host, List<String> segments, String name) {
  if (host == name) return true;
  return segments.any((segment) => segment.toLowerCase() == name);
}

/// `codsquadapp://lobby/<id>` / `codsquadapp://peacock/<id>` (and
/// `/lobby/<id>`, `/peacock/<id>`, or `/l/<id>` on https) — path is the
/// lobby id, not a game name. Query `lobby_id` still wins when present.
/// `https://codsquad.app/l/<id>` is the Universal Link.
String? _lobbyIdFromPath({
  required String host,
  required List<String> segments,
}) {
  if (host == 'lobby' || host == 'l' || host == 'peacock') {
    return _nonEmpty(segments.isNotEmpty ? segments.first : null);
  }
  if (_isShortLobbyLink(host: host, segments: segments) &&
      segments.length >= 2) {
    final next = segments[1].toLowerCase();
    if (!_reservedLobbyPathSegment(next)) {
      return _nonEmpty(segments[1]);
    }
  }
  for (final marker in const ['lobby', 'peacock']) {
    final index =
        segments.indexWhere((segment) => segment.toLowerCase() == marker);
    if (index >= 0 && index + 1 < segments.length) {
      final next = segments[index + 1].toLowerCase();
      if (!_reservedLobbyPathSegment(next)) {
        return _nonEmpty(segments[index + 1]);
      }
    }
  }
  return null;
}

/// HTTPS `/l/<id>` (or custom-scheme host `l`) is the short lobby path.
bool _isShortLobbyLink({
  required String host,
  required List<String> segments,
}) {
  if (host == 'l') return true;
  return segments.isNotEmpty && segments.first.toLowerCase() == 'l';
}

bool _reservedLobbyPathSegment(String segment) {
  const reserved = {
    'squad',
    'peacock',
    'lfg_matched',
    'lfg_alert',
    'availability_ping',
    'lobby_locked',
    'chat',
    'join',
    'l',
  };
  return reserved.contains(segment);
}

String? _gameNameFromPath({
  required String host,
  required List<String> segments,
}) {
  // Lobby / peacock path is the lobby id ([_lobbyIdFromPath]); game stays
  // on query.
  const markers = ['squad', 'lfg_matched'];
  if (markers.contains(host) && segments.isNotEmpty) {
    final first = segments.first.toLowerCase();
    if (!markers.contains(first) && first != 'lobby' && first != 'peacock') {
      return _nonEmpty(segments.first);
    }
  }
  for (final marker in markers) {
    final index =
        segments.indexWhere((segment) => segment.toLowerCase() == marker);
    if (index >= 0 && index + 1 < segments.length) {
      return _nonEmpty(segments[index + 1]);
    }
  }
  return null;
}

String? _joinCode({
  required String host,
  required List<String> segments,
  required Map<String, String> query,
}) {
  if (host == 'join') {
    return _nonEmpty(segments.isNotEmpty ? segments.first : null) ??
        _nonEmpty(query['code']);
  }
  final joinIndex = segments.indexOf('join');
  if (joinIndex < 0) return null;
  if (joinIndex + 1 < segments.length) {
    return _nonEmpty(segments[joinIndex + 1]) ?? _nonEmpty(query['code']);
  }
  return _nonEmpty(query['code']);
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

/// After-route result for [applyLobbyDeepLink]. Parse stays on
/// [locationForDeepLink] / [NotificationRoutes] — this only applies
/// THAT lobby. Malformed / missing id stays put (no splash hang).
class LobbyDeepLinkApply {
  const LobbyDeepLinkApply({
    this.location,
    this.selectedLobbyId,
    this.chatBind = ActiveLobbyChatBind.empty,
    this.subscribed = false,
    this.splashDown = false,
    this.stayedPut = false,
  });

  final String? location;
  final String? selectedLobbyId;
  final ActiveLobbyChatBind chatBind;
  final bool subscribed;
  final bool splashDown;

  /// Missing / malformed lobby id — stay put, do not hang on splash.
  final bool stayedPut;
}

/// Live hooks for [applyLobbyDeepLink] (wired from GoRouter / DeepLinkRouter).
class LobbyDeepLinkHooks {
  const LobbyDeepLinkHooks({
    this.selectLobby,
    this.subscribe,
    this.bindChat,
    this.dismissSplash,
  });

  final void Function(String selectedLobbyId)? selectLobby;

  /// After route: selectedLobbyId + _subscribeToCurrentLobby.
  final void Function(String selectedLobbyId)? subscribe;
  final void Function(String selectedLobbyId, {String? lobbyChatGroupId})?
      bindChat;
  final void Function()? dismissSplash;
}

LobbyDeepLinkHooks lobbyDeepLinkHooks = const LobbyDeepLinkHooks();

void bindLobbyDeepLinkHooks({
  void Function(String selectedLobbyId)? selectLobby,
  void Function(String selectedLobbyId)? subscribe,
  void Function(String selectedLobbyId, {String? lobbyChatGroupId})? bindChat,
  void Function()? dismissSplash,
}) {
  lobbyDeepLinkHooks = LobbyDeepLinkHooks(
    selectLobby: selectLobby,
    subscribe: subscribe,
    bindChat: bindChat,
    dismissSplash: dismissSplash,
  );
}

String? lobbyIdFromRoutedLocation(String? location) {
  if (location == null || location.isEmpty) return null;
  final uri = Uri.tryParse(location);
  if (uri == null) return null;
  return NotificationRoutes.lobbyIdFrom(
    Map<String, dynamic>.from(uri.queryParameters),
  );
}

String? _locationFromApplyRaw(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('/')) return raw;
  return locationForDeepLink(raw);
}

/// Single after-route apply used by notify tap, AppLinks, cold start, and
/// resume. FriendsMode still `/squad?lobby_id=`. Does not navigate — callers
/// go once.
LobbyDeepLinkApply applyLobbyDeepLink(
  String? raw, {
  Map<String, dynamic>? payload,
  ActiveLobbyChatBind currentBind = ActiveLobbyChatBind.empty,
  String? lobbyChatGroupId,
  void Function(String selectedLobbyId)? selectLobby,
  void Function(String selectedLobbyId)? subscribe,
  void Function()? dismissSplash,
}) {
  final trimmed = raw?.trim();
  if (payload == null && (trimmed == null || trimmed.isEmpty)) {
    return const LobbyDeepLinkApply(stayedPut: true);
  }
  if (trimmed != null &&
      trimmed.isNotEmpty &&
      !trimmed.startsWith('/') &&
      isMalformedAppLink(trimmed)) {
    return const LobbyDeepLinkApply(stayedPut: true);
  }

  String? location;
  String? lobbyId;
  if (payload != null) {
    final normalized = NotificationRoutes.normalize(payload);
    location = NotificationRoutes.locationFor(normalized);
    lobbyId = NotificationRoutes.lobbyIdFrom(normalized);
  }
  location ??= _locationFromApplyRaw(trimmed);
  lobbyId ??= lobbyIdFromRoutedLocation(location);

  if (lobbyId == null) {
    return LobbyDeepLinkApply(location: location, stayedPut: true);
  }

  final select = selectLobby ?? lobbyDeepLinkHooks.selectLobby;
  final sub = subscribe ?? lobbyDeepLinkHooks.subscribe;
  final splash = dismissSplash ?? lobbyDeepLinkHooks.dismissSplash;
  select?.call(lobbyId);
  sub?.call(lobbyId);
  lobbyDeepLinkHooks.bindChat?.call(
    lobbyId,
    lobbyChatGroupId: lobbyChatGroupId,
  );
  final chatBind = switchActiveLobbyChatBind(
    current: currentBind,
    nextLobbyId: lobbyId,
    nextLobbyChatGroupId: lobbyChatGroupId ?? '',
  );
  splash?.call();
  return LobbyDeepLinkApply(
    location: location,
    selectedLobbyId: lobbyId,
    chatBind: chatBind,
    subscribed: true,
    splashDown: true,
  );
}

/// How a product link arrived. Stubs AppLinks / FCM without a device.
enum PendingLinkSource {
  /// App was killed; user opened a URL or tapped a notification.
  coldStart,

  /// App was backgrounded; a pending URL or notification tap resumed it.
  resume,
}

/// Holds one resolved go_router location until [NotificationRoutes] is bound.
///
/// Cold start (`getInitialLink` / `getInitialMessage`) and background-resume
/// (`uriLinkStream` / `onMessageOpenedApp`) share this queue. Unknown URLs
/// and empty payloads do not invent a route.
class PendingLinkQueue {
  String? _location;
  PendingLinkSource? _source;

  String? get location => _location;
  PendingLinkSource? get source => _source;
  bool get isPending => _location != null;

  void clear() {
    _location = null;
    _source = null;
    NotificationRoutes.resetPendingFlush();
  }

  /// Keep [location] until [flush]. Null / unknown is ignored so a later
  /// resume can still deliver. The same location is stored once.
  void hold(String? location, {required PendingLinkSource source}) {
    if (location == null || location.isEmpty) return;
    if (_location == location) {
      _source ??= source;
      return;
    }
    _location = location;
    _source = source;
  }

  String? take() {
    final location = _location;
    clear();
    return location;
  }

  /// Open the pending location through [go] or [NotificationRoutes.go].
  /// Leaves it pending when no opener is bound yet. Applies THAT lobby
  /// once — AppLinks + queue + GoRouter must not double-go.
  String? flush({void Function(String location)? go}) {
    final location = _location;
    if (location == null) return null;
    final opener = go ?? NotificationRoutes.go;
    if (opener == null) return location;
    clear();
    NotificationRoutes.markPendingFlush(location);
    applyLobbyDeepLink(location);
    opener(location);
    return location;
  }

  /// Killed → open URL (`AppLinks.getInitialLink`).
  String? offerColdStartUrl(
    String? link, {
    bool? isIosSimulator,
    void Function()? dismissSplash,
    void Function(String message)? log,
    AppLinkAcceptGate? acceptGate,
  }) {
    return _offerUrl(
      link,
      PendingLinkSource.coldStart,
      isIosSimulator: isIosSimulator,
      dismissSplash: dismissSplash,
      log: log,
      acceptGate: acceptGate,
    );
  }

  /// Background-resume URL (`AppLinks.uriLinkStream`).
  String? offerResumeUrl(
    String? link, {
    bool? isIosSimulator,
    void Function()? dismissSplash,
    void Function(String message)? log,
    AppLinkAcceptGate? acceptGate,
  }) {
    return _offerUrl(
      link,
      PendingLinkSource.resume,
      isIosSimulator: isIosSimulator,
      dismissSplash: dismissSplash,
      log: log,
      acceptGate: acceptGate,
    );
  }

  String? offerColdStartUri(
    Uri? uri, {
    bool? isIosSimulator,
    void Function()? dismissSplash,
    void Function(String message)? log,
    AppLinkAcceptGate? acceptGate,
  }) {
    return offerColdStartUrl(
      uri?.toString(),
      isIosSimulator: isIosSimulator,
      dismissSplash: dismissSplash,
      log: log,
      acceptGate: acceptGate,
    );
  }

  String? offerResumeUri(
    Uri? uri, {
    bool? isIosSimulator,
    void Function()? dismissSplash,
    void Function(String message)? log,
    AppLinkAcceptGate? acceptGate,
  }) {
    return offerResumeUrl(
      uri?.toString(),
      isIosSimulator: isIosSimulator,
      dismissSplash: dismissSplash,
      log: log,
      acceptGate: acceptGate,
    );
  }

  /// Killed → notification tap (`FirebaseMessaging.getInitialMessage`).
  String? offerColdStartPayload(Map<String, dynamic>? data) {
    return _offerPayload(data, PendingLinkSource.coldStart);
  }

  /// Background-resume notification (`onMessageOpenedApp`).
  String? offerResumePayload(Map<String, dynamic>? data) {
    return _offerPayload(data, PendingLinkSource.resume);
  }

  String? offerColdStartRaw(String? raw) {
    return _offerRaw(raw, PendingLinkSource.coldStart);
  }

  String? offerResumeRaw(String? raw) {
    return _offerRaw(raw, PendingLinkSource.resume);
  }

  /// Stub of [main] AppLinks: killed → `getInitialLink`, then `uriLinkStream`.
  ({String? launch, String? resume}) consumeAppLinkStubs({
    String? initialLink,
    Uri? initialUri,
    String? resumeLink,
    Uri? resumeUri,
    bool? isIosSimulator,
    void Function()? dismissSplash,
    void Function(String message)? log,
    AppLinkAcceptGate? acceptGate,
  }) {
    final plan = planAppLinkListen(isIosSimulator: isIosSimulator);
    String? launch;
    if (plan.consumeInitialLink) {
      launch = offerColdStartUrl(
        initialLink ?? initialUri?.toString(),
        isIosSimulator: isIosSimulator,
        dismissSplash: dismissSplash,
        log: log,
        acceptGate: acceptGate,
      );
    }
    String? resume;
    if (plan.subscribeUriLinkStream) {
      resume = offerResumeUrl(
        resumeLink ?? resumeUri?.toString(),
        isIosSimulator: isIosSimulator,
        dismissSplash: dismissSplash,
        log: log,
        acceptGate: acceptGate,
      );
    }
    return (launch: launch, resume: resume);
  }

  /// Stub of killed vs background-resume for AASA `/l/*` Universal Links.
  /// Non-UL URLs are ignored so a later product resume can still deliver.
  ({String? launch, String? resume}) consumeUniversalLinkStubs({
    String? initialLink,
    String? resumeLink,
    bool? isIosSimulator,
    void Function()? dismissSplash,
    void Function(String message)? log,
    AppLinkAcceptGate? acceptGate,
  }) {
    String? offer(String? link, PendingLinkSource source) {
      if (link == null || isMalformedAppLink(link)) return null;
      if (!isLobbyUniversalLink(link)) return null;
      return source == PendingLinkSource.coldStart
          ? offerColdStartUrl(
              link,
              isIosSimulator: isIosSimulator,
              dismissSplash: dismissSplash,
              log: log,
              acceptGate: acceptGate,
            )
          : offerResumeUrl(
              link,
              isIosSimulator: isIosSimulator,
              dismissSplash: dismissSplash,
              log: log,
              acceptGate: acceptGate,
            );
    }

    final launch = offer(initialLink, PendingLinkSource.coldStart);
    final resume = offer(resumeLink, PendingLinkSource.resume);
    return (launch: launch, resume: resume);
  }

  /// Stub of FCM: killed → `getInitialMessage`, then `onMessageOpenedApp`.
  ({String? launch, String? resume}) consumeNotificationStubs({
    Map<String, dynamic>? initialMessage,
    String? initialRaw,
    Map<String, dynamic>? openedAppMessage,
    String? openedAppRaw,
  }) {
    final launch = initialMessage != null
        ? offerColdStartPayload(initialMessage)
        : offerColdStartRaw(initialRaw);
    final resume = openedAppMessage != null
        ? offerResumePayload(openedAppMessage)
        : offerResumeRaw(openedAppRaw);
    return (launch: launch, resume: resume);
  }

  String? _offerUrl(
    String? link,
    PendingLinkSource source, {
    bool? isIosSimulator,
    void Function()? dismissSplash,
    void Function(String message)? log,
    AppLinkAcceptGate? acceptGate,
  }) {
    if (link == null || link.trim().isEmpty) return null;
    if (isMalformedAppLink(link)) return null;
    if (acceptGate != null &&
        !acceptGate.delivers(link, isIosSimulator: isIosSimulator)) {
      return null;
    }
    final location = prepareLiveAppLink(
      link,
      isIosSimulator: isIosSimulator,
      dismissSplash: dismissSplash,
      log: log,
    );
    hold(location, source: source);
    return location;
  }

  String? _offerPayload(Map<String, dynamic>? data, PendingLinkSource source) {
    if (data == null || data.isEmpty) return null;
    final location = NotificationRoutes.locationFor(data);
    hold(location, source: source);
    return location;
  }

  String? _offerRaw(String? raw, PendingLinkSource source) {
    if (raw == null || raw.trim().isEmpty) return null;
    final mapped = NotificationRoutes.mapFromRaw(raw);
    final location = mapped != null
        ? NotificationRoutes.locationFor(mapped)
        : locationForDeepLink(raw.trim());
    hold(location, source: source);
    return location;
  }
}

/// Live queue used by AppLinks, FCM taps, and [NotificationRoutes.bindRouter].
final pendingLinkQueue = PendingLinkQueue();
