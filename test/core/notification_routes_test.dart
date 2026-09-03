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
        'type': 'peacock_assigned',
        'lobby_id': 'lobby-9',
      }),
      '/squad?lobby_id=lobby-9',
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

  test('lfg_alert opens chat; lfg_matched opens /squad with lobby', () {
    expect(
      NotificationRoutes.locationFor({
        'type': 'lfg_alert',
        'squad_id': 'squad-1',
      }),
      '/chat/squad-1',
    );
    expect(
      NotificationRoutes.locationFor({'type': 'lfg_alert'}),
      '/chat',
    );
    expect(
      NotificationRoutes.locationFor({
        'type': 'lfg_matched',
        'game_name': 'Warzone',
        'lobby_id': 'lobby-9',
      }),
      '/squad/Warzone?lobby_id=lobby-9',
    );
    expect(
      NotificationRoutes.locationFor({
        'type': 'lfg_matched',
        'lobby_id': 'lobby-9',
      }),
      '/squad?lobby_id=lobby-9',
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

  test('peacock_assigned tap navigates to squad with lobby_id', () {
    String? opened;
    NotificationRoutes.go = (location) => opened = location;
    NotificationRoutes.openRaw(
      '{"type":"peacock_assigned","game_name":"Warzone","lobby_id":"lobby-9"}',
    );
    expect(opened, '/squad/Warzone?lobby_id=lobby-9');
    NotificationRoutes.go = null;
  });

  test('screen squad|lobby reuses lobby_id on /squad', () {
    expect(
      NotificationRoutes.locationFor({
        'screen': 'squad',
        'lobby_id': 'lobby-9',
        'game_name': 'Warzone',
      }),
      '/squad/Warzone?lobby_id=lobby-9',
    );
    expect(
      NotificationRoutes.locationFor({
        'screen': 'lobby',
        'lobby_id': 'lobby-9',
      }),
      '/squad?lobby_id=lobby-9',
    );
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
