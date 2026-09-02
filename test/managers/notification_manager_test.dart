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

  test('foreground FCM shows local when notification payload is present', () {
    expect(
      NotificationService.shouldShowForegroundLocal(
        const RemoteMessage(
          notification: RemoteNotification(title: 'Hi', body: 'There'),
        ),
      ),
      isTrue,
    );
    expect(
      NotificationService.shouldShowForegroundLocal(const RemoteMessage()),
      isFalse,
    );
  });
}
