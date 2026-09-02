import 'package:flutter/material.dart';
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

  test('peacock_assigned and spot_available open /squad with game and lobby',
      () {
    expect(
      NotificationRoutes.locationFor({
        'type': 'peacock_assigned',
        'game_name': 'Warzone',
      }),
      '/squad/Warzone',
    );
    expect(
      NotificationRoutes.locationFor({
        'type': 'peacock_assigned',
        'game_name': 'Warzone',
        'lobby_id': 'lobby-9',
      }),
      '/squad/Warzone?lobby_id=lobby-9',
    );
    expect(
      NotificationRoutes.locationFor({'type': 'peacock_assigned'}),
      '/squad',
    );
    expect(
      NotificationRoutes.locationFor({
        'type': 'spot_available',
        'game_name': 'MW3',
        'lobby_id': 'abc',
      }),
      '/squad/MW3?lobby_id=abc',
    );
    expect(
      NotificationRoutes.locationFor({
        'type': 'peacock_assigned',
        'lobby_id': '',
      }),
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

  testWidgets('navigate retries when the navigator context is missing',
      (tester) async {
    NotificationRoutes.router = null;
    NotificationRoutes.navigatorKey = GlobalKey<NavigatorState>();
    NotificationRoutes.go = NotificationRoutes.navigate;
    // No context and no router — should log and schedule a frame, not throw.
    expect(
      () => NotificationRoutes.open({'type': 'chat', 'chatGroupId': 'g1'}),
      returnsNormally,
    );
    await tester.pump();
    NotificationRoutes.go = null;
    NotificationRoutes.navigatorKey = null;
  });
}
