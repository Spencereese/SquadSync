import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  static String? locationFor(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final screen = data['screen']?.toString();
    final chatId = _firstNonEmpty(data, const [
      'chatGroupId',
      'chat_group_id',
      'groupId',
      'group_id',
    ]);
    final gameName = _firstNonEmpty(data, const ['gameName', 'game_name']);
    final lobbyId = _firstNonEmpty(data, const ['lobbyId', 'lobby_id']);

    switch (type) {
      case 'chat':
        if (chatId != null) return '/chat/$chatId';
        return '/chat';
      case 'lobby_join':
      case 'direct_invite':
      case 'momentum':
      case 'spot_available':
      case 'peacock_assigned':
        return _squadLocation(gameName: gameName, lobbyId: lobbyId);
      default:
        if (screen == 'chat') {
          return chatId != null ? '/chat/$chatId' : '/chat';
        }
        if (screen == 'squad' || screen == 'lobby') {
          return '/squad';
        }
        return null;
    }
  }

  static void open(Map<String, dynamic> data) {
    final location = locationFor(data);
    if (location != null) {
      go?.call(location);
    }
  }

  /// Existing `/squad` routes only. [lobbyId] is a query param so
  /// the squad tab can select the lobby without a new path.
  static String _squadLocation({String? gameName, String? lobbyId}) {
    final path = gameName != null
        ? '/squad/${Uri.encodeComponent(gameName)}'
        : '/squad';
    if (lobbyId == null) return path;
    return '$path?lobby_id=${Uri.encodeComponent(lobbyId)}';
  }

  static String? _firstNonEmpty(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
