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

/// Pure mapping from an App Link / custom-scheme URI to a go_router
/// location. Returns null for auth callbacks and unknown URIs.
///
/// Peacock card, notification, `lfg_matched` / `lfg_alert` / peacock /
/// lobby URLs all go through here then [NotificationRoutes.locationFor].
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
  final lobbyId = _nonEmpty(query['lobby_id']) ?? _nonEmpty(query['lobbyId']);
  var gameName = _nonEmpty(query['game_name']) ?? _nonEmpty(query['gameName']);
  gameName ??= _gameNameFromPath(host: host, segments: segments);

  final mappedType = _mappedType(
    queryType: queryType,
    host: host,
    segments: segments,
  );
  var screen = queryScreen;
  if (screen.isEmpty) {
    if (_matchesName(host, segments, 'lobby')) {
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
  if (_matchesName(host, segments, 'peacock')) return 'peacock_assigned';
  return null;
}

bool _matchesName(String host, List<String> segments, String name) {
  if (host == name) return true;
  return segments.any((segment) => segment.toLowerCase() == name);
}

String? _gameNameFromPath({
  required String host,
  required List<String> segments,
}) {
  const markers = ['squad', 'lobby', 'peacock', 'lfg_matched'];
  if (markers.contains(host) && segments.isNotEmpty) {
    final first = segments.first.toLowerCase();
    if (!markers.contains(first)) {
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
