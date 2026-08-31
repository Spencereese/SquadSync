import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/notification_routes.dart';

void main() {
  test('chat payload routes to an existing chat location', () {
    expect(
      NotificationRoutes.locationFor({
        'type': 'chat',
        'chatGroupId': 'group-1',
      }),
      '/chat/group-1',
    );
    expect(
      NotificationRoutes.locationFor({'type': 'chat'}),
      '/chat',
    );
  });

  test('lobby payloads route to /squad', () {
    expect(
      NotificationRoutes.locationFor({
        'type': 'lobby_join',
        'gameName': 'Warzone',
      }),
      '/squad/Warzone',
    );
    expect(
      NotificationRoutes.locationFor({'type': 'direct_invite'}),
      '/squad',
    );
  });

  test('unknown type does not invent a route', () {
    expect(NotificationRoutes.locationFor({'type': 'unknown'}), isNull);
  });

  test('open calls go when a handler is bound', () {
    String? opened;
    NotificationRoutes.go = (location) => opened = location;
    NotificationRoutes.open({'type': 'chat', 'chatGroupId': 'g1'});
    expect(opened, '/chat/g1');
    NotificationRoutes.go = null;
  });
}
