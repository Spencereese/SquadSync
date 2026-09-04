import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/notification_hygiene.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/notification_service.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

void main() {
  setUp(() {
    NotificationHygieneStore.instance.reset();
    NotificationService.currentUidForHygiene = null;
  });

  tearDown(() {
    NotificationManager.showLocal = null;
    NotificationHygieneStore.instance.reset();
    NotificationService.currentUidForHygiene = null;
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

  test('muted squad suppresses NotificationManager local show', () async {
    var shown = false;
    NotificationManager.showLocal = (title, body, payload) async {
      shown = true;
    };
    NotificationHygieneStore.instance.mutedSquadIds.add('lobby-9');

    await NotificationManager().showNotification(
      title: 'Alex is on now',
      body: 'Alex is ready to play Warzone',
      type: 'availability_ping',
      lobbyId: 'lobby-9',
      gameName: 'Warzone',
    );

    expect(shown, isFalse);
  });

  test('quiet hours suppress NotificationManager local show', () async {
    var shown = false;
    NotificationManager.showLocal = (title, body, payload) async {
      shown = true;
    };
    NotificationHygieneStore.instance
      ..quietHoursEnabled = true
      ..startMinutes = 22 * 60
      ..endMinutes = 8 * 60
      ..clock = () => DateTime(2026, 1, 1, 23);

    await NotificationManager().showNotification(
      title: 'Squad locked',
      body: "Everyone's ready",
      type: 'lobby_locked',
      lobbyId: 'lobby-9',
    );

    expect(shown, isFalse);
  });

  test('outside quiet hours unmuted squad still shows locally', () async {
    var shown = false;
    NotificationManager.showLocal = (title, body, payload) async {
      shown = true;
    };
    NotificationHygieneStore.instance
      ..quietHoursEnabled = true
      ..clock = () => DateTime(2026, 1, 1, 12);

    await NotificationManager().showNotification(
      title: 'Spot ready',
      body: 'Your peacock queue assigned a lobby',
      type: 'peacock_assigned',
      lobbyId: 'lobby-9',
    );

    expect(shown, isTrue);
  });

  test('service local show gate matches mute and quiet hours', () {
    NotificationHygieneStore.instance.mutedSquadIds.add('lobby-9');
    expect(
      NotificationService.shouldSuppressLocalShow(
        {'type': 'availability_ping', 'lobby_id': 'lobby-9'},
      ),
      isTrue,
    );
    NotificationHygieneStore.instance.reset();
    NotificationHygieneStore.instance
      ..quietHoursEnabled = true
      ..clock = () => DateTime(2026, 1, 1, 23);
    expect(
      NotificationService.shouldSuppressLocalShow(
        {'type': 'peacock_assigned', 'lobby_id': 'other'},
      ),
      isTrue,
    );
  });

  test('service send gate drops all recipients in quiet hours', () {
    NotificationHygieneStore.instance
      ..quietHoursEnabled = true
      ..clock = () => DateTime(2026, 1, 1, 23);

    expect(
      NotificationService.recipientsAfterHygiene(
        recipientUids: const ['u2', 'u3'],
        data: const {'type': 'availability_ping', 'lobby_id': 'lobby-9'},
        currentUid: 'u1',
      ),
      isEmpty,
    );
  });

  test('service send gate drops self only when this squad is muted', () {
    NotificationHygieneStore.instance.mutedSquadIds.add('lobby-9');
    NotificationService.currentUidForHygiene = () => 'me';

    expect(
      NotificationService.recipientsAfterHygiene(
        recipientUids: const ['me', 'u2'],
        data: const {'type': 'peacock_assigned', 'lobby_id': 'lobby-9'},
      ),
      ['u2'],
    );
  });

  test('hygiene does not add a second presenter — taps still use routes', () {
    expect(
      NotificationRoutes.locationFor({
        'type': 'availability_ping',
        'lobby_id': 'lobby-9',
        'game_name': 'Warzone',
      }),
      '/squad/Warzone?lobby_id=lobby-9',
    );
    expect(
      planPeacockSelfNotify(
        notificationId: 'n1',
        currentUid: 'me',
        isForeground: true,
        locallyPresentedIds: {},
      ).wouldDoubleNotifySelf,
      isFalse,
    );
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
