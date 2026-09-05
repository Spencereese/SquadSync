import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'deep_link_routes.dart';

/// Maps FCM / local-notification payloads to existing go_router locations.
class NotificationRoutes {
  NotificationRoutes._();

  static void Function(String location)? go;
  static GoRouter? router;
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Wire taps after GoRouter is built. Prefers the live navigator; falls
  /// back to the stored [GoRouter] and one post-frame retry so
  /// [getInitialMessage] does not silently drop before the first frame.
  static void bindRouter(GoRouter goRouter, GlobalKey<NavigatorState> key) {
    router = goRouter;
    navigatorKey = key;
    go = navigate;
  }

  /// Older name used by app_widgets / tests.
  static void bindNavigator(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
    go = navigate;
  }

  static void navigate(String location) {
    final context = navigatorKey?.currentContext;
    if (context != null && context.mounted) {
      GoRouter.of(context).go(location);
      return;
    }
    final stored = router;
    if (stored != null) {
      stored.go(location);
      return;
    }
    debugPrint(
        'NotificationRoutes: navigator not ready for $location; retrying next frame');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final retryContext = navigatorKey?.currentContext;
      if (retryContext != null && retryContext.mounted) {
        GoRouter.of(retryContext).go(location);
        return;
      }
      if (router != null) {
        router!.go(location);
        return;
      }
      debugPrint(
          'NotificationRoutes: dropped $location (no GoRouter / unmounted key)');
    });
  }

  /// Flatten FCM / APNS / local shapes so [locationFor] sees `type` and
  /// `lobby_id` at the top level. Nested `data` / `payload` maps or JSON
  /// strings fill missing keys only. Idempotent.
  static Map<String, dynamic> normalize(Map<String, dynamic> data) {
    final merged = <String, dynamic>{};
    void absorb(Map map, {required bool overwrite}) {
      map.forEach((key, value) {
        final k = key.toString();
        if (!overwrite && merged.containsKey(k)) return;
        merged[k] = value;
      });
    }

    absorb(data, overwrite: true);
    for (final nestedKey in const ['data', 'payload']) {
      final nested = _mapFromNested(merged[nestedKey]);
      if (nested != null) absorb(nested, overwrite: false);
    }

    final type = canonicalType(merged['type']?.toString());
    if (type != null) merged['type'] = type;
    final screen = merged['screen']?.toString().trim().toLowerCase();
    if (screen != null && screen.isNotEmpty) merged['screen'] = screen;
    final lobbyId = lobbyIdFrom(merged);
    if (lobbyId != null) merged['lobby_id'] = lobbyId;
    final gameName = _firstNonEmpty(merged, const [
      'game_name',
      'gameName',
      'game',
    ]);
    if (gameName != null) merged['game_name'] = gameName;
    return merged;
  }

  /// Canonical FCM / local type. Hyphens, case, and I'm-on / peacock /
  /// lock aliases collapse onto the existing [locationFor] switch.
  static String? canonicalType(String? raw) {
    final t = raw?.trim().toLowerCase().replaceAll('-', '_');
    if (t == null || t.isEmpty || t == 'null') return null;
    switch (t) {
      case 'peacock':
      case 'peacock_assigned':
      case 'peacock_assign':
      case 'peacock_assignment':
        return 'peacock_assigned';
      case 'availability_ping':
      case 'availability':
      case 'im_on':
      case 'i_am_on':
      case 'iam_on':
      case 'on_now':
        return 'availability_ping';
      case 'lobby_locked':
      case 'lobby_lock':
      case 'ready_lock':
        return 'lobby_locked';
      default:
        return t;
    }
  }

  /// Lobby id from the shapes real-device FCM actually sends.
  static String? lobbyIdFrom(Map<String, dynamic> data) {
    final direct = _firstNonEmpty(data, const [
      'lobby_id',
      'lobbyId',
      'lobbyID',
    ]);
    if (direct != null) return direct;
    final lobby = data['lobby'];
    if (lobby is Map) {
      return _firstNonEmpty(
        lobby.map((k, v) => MapEntry(k.toString(), v)),
        const ['lobby_id', 'lobbyId', 'id'],
      );
    }
    return _nonEmpty(lobby);
  }

  static String? locationFor(Map<String, dynamic> data) {
    final n = normalize(data);
    final type = n['type']?.toString();
    final screen = n['screen']?.toString();
    final chatId = _firstNonEmpty(n, const [
      'chatGroupId',
      'chat_group_id',
      'groupId',
      'group_id',
    ]);
    final gameName = _firstNonEmpty(n, const ['gameName', 'game_name']);
    final lobbyId = lobbyIdFrom(n);

    String? routed;
    switch (type) {
      case 'chat':
        routed = chatId != null ? '/chat/$chatId' : '/chat';
        break;
      case 'lobby_join':
      case 'direct_invite':
      case 'momentum':
      case 'spot_available':
      case 'peacock':
      case 'peacock_assigned':
      case 'lfg_matched':
      case 'availability_ping':
      case 'lobby_locked':
      case 'lobby':
      case 'squad':
        if (type == 'availability_ping' && lobbyId == null) {
          final squadId = _firstNonEmpty(n, const [
            'squad_id',
            'squadId',
            'chatGroupId',
            'chat_group_id',
            'groupId',
            'group_id',
          ]);
          if (squadId != null) {
            routed = '/chat/$squadId';
            break;
          }
        }
        routed = _squadLocation(gameName: gameName, lobbyId: lobbyId);
        break;
      case 'lfg_alert':
        final squadId = _firstNonEmpty(n, const [
          'squad_id',
          'squadId',
          'chatGroupId',
          'chat_group_id',
          'groupId',
          'group_id',
        ]);
        routed = squadId != null ? '/chat/$squadId' : '/chat';
        break;
      default:
        if (screen == 'chat') {
          routed = chatId != null ? '/chat/$chatId' : '/chat';
        } else if (screen == 'squad' || screen == 'lobby') {
          routed = _squadLocation(gameName: gameName, lobbyId: lobbyId);
        }
    }

    if (routed != null) return routed;

    // Real-device taps: if a lobby id is present, always open that lobby.
    if (lobbyId != null) {
      return _squadLocation(gameName: gameName, lobbyId: lobbyId);
    }

    final link = _productLinkFrom(n);
    if (link != null) {
      return locationForDeepLink(link);
    }
    return null;
  }

  static void open(Map<String, dynamic> data) {
    final location = locationFor(data);
    if (location != null) {
      go?.call(location);
    }
  }

  /// Local-notification tap payload is JSON on [NotificationResponse.payload].
  /// Real-device FCM / APNS also delivers URL, query-string, or nested JSON.
  static void openRaw(String? raw) {
    if (raw == null || raw.isEmpty) return;
    final mapped = mapFromRaw(raw);
    if (mapped != null) {
      open(mapped);
      return;
    }
    final location = locationForDeepLink(raw.trim());
    if (location != null) {
      go?.call(location);
    }
  }

  /// JSON, URI-decoded JSON, or `type=&lobby_id=` query string.
  /// URLs (`codsquadapp://…`, `https://codsquad.app/l/…`) stay on
  /// [locationForDeepLink] via [openRaw].
  static Map<String, dynamic>? mapFromRaw(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final json = _mapFromJsonText(trimmed);
    if (json != null) return json;

    try {
      final decoded = Uri.decodeFull(trimmed);
      if (decoded != trimmed) {
        final fromDecoded = _mapFromJsonText(decoded);
        if (fromDecoded != null) return fromDecoded;
      }
    } catch (_) {}

    if (trimmed.contains('://') || trimmed.startsWith('{')) return null;
    if (!trimmed.contains('=')) return null;
    final query = Uri.splitQueryString(trimmed);
    if (query.isEmpty) return null;
    const keys = [
      'type',
      'screen',
      'lobby_id',
      'lobbyId',
      'lobby',
      'game_name',
      'gameName',
    ];
    if (!keys.any(query.containsKey)) return null;
    return Map<String, dynamic>.from(query);
  }

  /// Existing `/squad` routes only. [lobbyId] is a query param so
  /// the squad tab can select the lobby without a new path.
  static String _squadLocation({String? gameName, String? lobbyId}) {
    final path =
        gameName != null ? '/squad/${Uri.encodeComponent(gameName)}' : '/squad';
    if (lobbyId == null) return path;
    return '$path?lobby_id=${Uri.encodeComponent(lobbyId)}';
  }

  static String? _firstNonEmpty(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = _nonEmpty(data[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    if (value is Map || value is List) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  static Map<String, dynamic>? _mapFromNested(dynamic nested) {
    if (nested is Map) {
      return nested.map((k, v) => MapEntry(k.toString(), v));
    }
    if (nested is String) return _mapFromJsonText(nested);
    return null;
  }

  static Map<String, dynamic>? _mapFromJsonText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  static String? _productLinkFrom(Map<String, dynamic> data) {
    const keys = [
      'deep_link',
      'deepLink',
      'deeplink',
      'link',
      'url',
      'click_action',
    ];
    for (final key in keys) {
      final value = _nonEmpty(data[key]);
      if (value != null && _looksLikeProductLink(value)) return value;
    }
    return null;
  }

  static bool _looksLikeProductLink(String value) {
    final v = value.trim().toLowerCase();
    if (v.startsWith('codsquadapp://')) return true;
    if (v.startsWith('/squad')) return true;
    if (v.startsWith('https://codsquad.app/')) return true;
    if (v.startsWith('https://www.codsquad.app/')) return true;
    if (v.startsWith('https://lobbiesync.app/')) return true;
    if (v.startsWith('https://www.lobbiesync.app/')) return true;
    return false;
  }
}
