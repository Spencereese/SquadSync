import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/notification_service.dart';

void main() {
  tearDown(() {
    NotificationManager.showLocal = null;
  });

  test('showNotification displays a local notification payload', () async {
    String? shownTitle;
    String? shownBody;
    Map<String, dynamic>? shownPayload;

    NotificationManager.showLocal = (title, body, payload) async {
      shownTitle = title;
      shownBody = body;
      shownPayload = payload;
    };

    await NotificationManager().showNotification(
      title: 'Spot ready',
      body: 'Your peacock queue assigned a lobby',
    );

    expect(shownTitle, 'Spot ready');
    expect(shownBody, 'Your peacock queue assigned a lobby');
    expect(shownPayload, {'type': 'local'});
  });

  test('peacock passes real route fields instead of type=local', () async {
    Map<String, dynamic>? shownPayload;

    NotificationManager.showLocal = (title, body, payload) async {
      shownPayload = payload;
    };

    await NotificationManager().showNotification(
      title: 'Spot ready',
      body: 'Your peacock queue assigned a lobby',
      type: 'peacock_assigned',
      lobbyId: 'lobby-9',
      gameName: 'Warzone',
    );

    expect(shownPayload, {
      'type': 'peacock_assigned',
      'lobby_id': 'lobby-9',
      'game_name': 'Warzone',
    });
  });

  test('foreground FCM local show is Android-only', () {
    const withNotification = RemoteMessage(
      notification: RemoteNotification(title: 'Hi', body: 'There'),
    );
    expect(
      NotificationService.shouldShowForegroundLocal(
        withNotification,
        isAndroid: true,
      ),
      isTrue,
    );
    expect(
      NotificationService.shouldShowForegroundLocal(
        withNotification,
        isAndroid: false,
      ),
      isFalse,
    );
    expect(
      NotificationService.shouldShowForegroundLocal(
        const RemoteMessage(),
        isAndroid: true,
      ),
      isFalse,
    );
  });
}
