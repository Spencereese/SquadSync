import 'package:flutter/foundation.dart';
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
String peacockCardDeepLink({
  String? lobbyId,
  String? gameName,
}) {
  return Uri(
    scheme: kSimulatorDeepLinkScheme,
    host: 'peacock',
    queryParameters: {
      if (_nonEmpty(lobbyId) != null) 'lobby_id': lobbyId!.trim(),
      if (_nonEmpty(gameName) != null) 'game_name': gameName!.trim(),
    },
  ).toString();
}

/// Chat peacock card tap. Same parse + [NotificationRoutes.go] as
/// notification taps and App Links.
void openPeacockCard({
  String? lobbyId,
  String? gameName,
  void Function(String location)? go,
}) {
  final location = locationForDeepLink(
    peacockCardDeepLink(lobbyId: lobbyId, gameName: gameName),
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

/// Copy [lobbyShareDeepLink] then open the system share sheet.
/// Live path: lobby header. Tests inject [copy] / [share].
Future<String> shareLobbyLink({
  required String lobbyId,
  Future<void> Function(String link)? copy,
  Future<void> Function(String link)? share,
}) async {
  final link = lobbyShareDeepLink(lobbyId: lobbyId);
  await (copy ?? _copyLobbyLinkToClipboard)(link);
  try {
    await (share ?? _shareLobbyLinkSheet)(link);
  } catch (_) {
    // Clipboard already holds [link].
  }
  return link;
}

Future<void> _copyLobbyLinkToClipboard(String link) {
  return Clipboard.setData(ClipboardData(text: link));
}

Future<void> _shareLobbyLinkSheet(String link) {
  return SharePlus.instance.share(ShareParams(text: link));
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
  Uri? uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return locationForDeepLink(trimmed);
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

/// Pure mapping from an App Link / custom-scheme URI to a go_router
/// location. Returns null for auth callbacks and unknown URIs.
///
/// Peacock card, notification, `lfg_matched` / `lfg_alert` /
/// `availability_ping` / peacock / lobby URLs all go through here then
/// [NotificationRoutes.locationFor].
String? locationForDeepLink(String link) {
  final trimmed = link.trim();
  if (trimmed.isEmpty) return null;
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
  return null;
}

bool _matchesName(String host, List<String> segments, String name) {
  if (host == name) return true;
  return segments.any((segment) => segment.toLowerCase() == name);
}

/// `codsquadapp://lobby/<id>` (and `/lobby/<id>` or `/l/<id>` on https)
/// — path is the lobby id, not a game name. Query `lobby_id` still wins
/// when present. `https://codsquad.app/l/<id>` is the Universal Link.
String? _lobbyIdFromPath({
  required String host,
  required List<String> segments,
}) {
  if (host == 'lobby' || host == 'l') {
    return _nonEmpty(segments.isNotEmpty ? segments.first : null);
  }
  if (_isShortLobbyLink(host: host, segments: segments) &&
      segments.length >= 2) {
    final next = segments[1].toLowerCase();
    if (!_reservedLobbyPathSegment(next)) {
      return _nonEmpty(segments[1]);
    }
  }
  final lobbyIndex =
      segments.indexWhere((segment) => segment.toLowerCase() == 'lobby');
  if (lobbyIndex >= 0 && lobbyIndex + 1 < segments.length) {
    final next = segments[lobbyIndex + 1].toLowerCase();
    if (!_reservedLobbyPathSegment(next)) {
      return _nonEmpty(segments[lobbyIndex + 1]);
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
  // Lobby path is the lobby id ([_lobbyIdFromPath]); game stays on query.
  const markers = ['squad', 'peacock', 'lfg_matched'];
  if (markers.contains(host) && segments.isNotEmpty) {
    final first = segments.first.toLowerCase();
    if (!markers.contains(first) && first != 'lobby') {
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
