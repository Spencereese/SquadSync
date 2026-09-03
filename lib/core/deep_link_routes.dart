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

/// Pure mapping from an App Link / custom-scheme URI to a go_router
/// location. Returns null for auth callbacks and unknown URIs.
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

  final screen = (query['screen'] ?? '').toLowerCase();
  final type = (query['type'] ?? '').toLowerCase();
  final lobbyId = _nonEmpty(query['lobby_id']) ?? _nonEmpty(query['lobbyId']);
  var gameName = _nonEmpty(query['game_name']) ?? _nonEmpty(query['gameName']);

  final hostIsSquad = host == 'squad' || host == 'lobby' || host == 'peacock';
  final pathIsSquad = segments.contains('squad') ||
      segments.contains('lobby') ||
      segments.contains('peacock');
  final queryIsSquad = screen == 'squad' ||
      screen == 'lobby' ||
      type == 'peacock_assigned';

  if (!hostIsSquad && !pathIsSquad && !queryIsSquad) {
    return null;
  }

  if (host == 'squad' && segments.isNotEmpty) {
    gameName ??= _nonEmpty(segments.first);
  } else if (segments.contains('squad')) {
    final index = segments.indexOf('squad');
    if (index + 1 < segments.length) {
      gameName ??= _nonEmpty(segments[index + 1]);
    }
  }

  final isPeacock = host == 'peacock' ||
      segments.contains('peacock') ||
      type == 'peacock_assigned';

  return NotificationRoutes.locationFor({
    if (isPeacock) 'type': 'peacock_assigned',
    if (!isPeacock) 'screen': screen.isNotEmpty ? screen : 'squad',
    if (lobbyId != null) 'lobby_id': lobbyId,
    if (gameName != null) 'game_name': gameName,
  });
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
