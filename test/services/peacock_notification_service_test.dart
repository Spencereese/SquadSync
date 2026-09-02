import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/services/peacock_notification_service.dart';

void main() {
  tearDown(() {
    NotificationManager.showLocal = null;
    PeacockNotificationService.resetTestHooks();
  });

  group('planPeacockSelfNotify', () {
    test('foreground Realtime is local only — no FCM to self', () {
      final plan = planPeacockSelfNotify(
        notificationId: 'n1',
        currentUid: 'uid-1',
        isForeground: true,
        locallyPresentedIds: {},
      );
      expect(plan.showLocal, isTrue);
      expect(plan.sendFcmToSelf, isFalse);
      expect(plan.recipientUids, isEmpty);
      expect(plan.wouldDoubleNotifySelf, isFalse);
    });

    test('background is FCM only — no local', () {
      final plan = planPeacockSelfNotify(
        notificationId: 'n1',
        currentUid: 'uid-1',
        isForeground: false,
        locallyPresentedIds: {},
      );
      expect(plan.showLocal, isFalse);
      expect(plan.sendFcmToSelf, isTrue);
      expect(plan.recipientUids, ['uid-1']);
      expect(plan.wouldDoubleNotifySelf, isFalse);
    });

    test('already presented locally skips FCM for that notificationId', () {
      final plan = planPeacockSelfNotify(
        notificationId: 'n1',
        currentUid: 'uid-1',
        isForeground: false,
        locallyPresentedIds: {'n1'},
      );
      expect(plan.showLocal, isFalse);
      expect(plan.sendFcmToSelf, isFalse);
      expect(plan.recipientUids, isEmpty);
    });

    test('one handle never local+FCM to the same uid', () {
      const uid = 'uid-1';
      for (final foreground in [true, false]) {
        for (final alreadyLocal in [true, false]) {
          final plan = planPeacockSelfNotify(
            notificationId: 'n1',
            currentUid: uid,
            isForeground: foreground,
            locallyPresentedIds: alreadyLocal ? {'n1'} : <String>{},
          );
          expect(plan.wouldDoubleNotifySelf, isFalse);
          if (plan.showLocal) {
            expect(plan.sendFcmToSelf, isFalse);
            expect(plan.recipientUids.contains(uid), isFalse);
          }
        }
      }
    });
  });

  group('handleNotification', () {
    Map<String, dynamic> record({String id = 'n1'}) => {
          'id': id,
          'title': 'Spot ready',
          'body': 'Your peacock queue assigned a lobby',
          'data': {
            'type': 'peacock_assigned',
            'lobby_id': 'lobby-9',
            'game_name': 'Warzone',
            'spot_index': '2',
          },
        };

    Future<
        ({
          List<Map<String, dynamic>> local,
          List<List<String>> fcm,
          List<String> sent,
        })> runHandle({
      required bool foreground,
      String uid = 'uid-1',
      Map<String, dynamic>? payload,
    }) async {
      final local = <Map<String, dynamic>>[];
      final fcm = <List<String>>[];
      final sent = <String>[];

      NotificationManager.showLocal = (title, body, payload) async {
        local.add({'title': title, 'body': body, ...payload});
      };
      PeacockNotificationService.isForegroundHook = () => foreground;
      PeacockNotificationService.currentUidHook = () => uid;
      PeacockNotificationService.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        fcm.add(List<String>.from(recipientUids));
      };
      PeacockNotificationService.markSentHook = (id) async {
        sent.add(id);
      };

      await PeacockNotificationService.handleNotification(payload ?? record());
      return (local: local, fcm: fcm, sent: sent);
    }

    test('foreground handle shows local and does not FCM same uid', () async {
      final result = await runHandle(foreground: true);

      expect(result.local, isNotEmpty);
      expect(result.local.first['type'], 'peacock_assigned');
      expect(result.local.first['lobby_id'], 'lobby-9');
      expect(result.fcm, isEmpty);
      expect(result.sent, ['n1']);
    });

    test('background handle FCMs once and does not show local', () async {
      final result = await runHandle(foreground: false);

      expect(result.local, isEmpty);
      expect(result.fcm, [
        ['uid-1']
      ]);
      expect(result.sent, ['n1']);
    });

    test('one handle never local+FCM to the same uid', () async {
      for (final foreground in [true, false]) {
        PeacockNotificationService.resetTestHooks();
        NotificationManager.showLocal = null;
        final result = await runHandle(foreground: foreground);
        final fcmUids = result.fcm.expand((uids) => uids);
        expect(result.local.isNotEmpty && fcmUids.contains('uid-1'), isFalse);
        expect(result.sent, ['n1']);
      }
    });

    test('second handle of same id does not local+FCM again', () async {
      final first = await runHandle(foreground: true);
      expect(first.local, isNotEmpty);
      expect(first.fcm, isEmpty);

      final second = await runHandle(foreground: false);
      expect(second.local, isEmpty);
      expect(second.fcm, isEmpty);
      expect(second.sent, ['n1']);
    });
  });
}
