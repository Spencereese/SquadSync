/// Maps FCM / local-notification payloads to existing go_router locations.
class NotificationRoutes {
  NotificationRoutes._();

  static void Function(String location)? go;

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

    switch (type) {
      case 'chat':
        if (chatId != null) return '/chat/$chatId';
        return '/chat';
      case 'lobby_join':
      case 'direct_invite':
      case 'momentum':
      case 'spot_available':
        if (gameName != null) {
          return '/squad/${Uri.encodeComponent(gameName)}';
        }
        return '/squad';
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
