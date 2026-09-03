import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';
import 'package:squad_sync/services/peacock_notification_service.dart';

void main() {
  tearDown(() {
    NotificationManager.showLocal = null;
    PeacockNotificationService.resetTestHooks();
  });

  group('peacockLifecycleIsForeground', () {
    test('null, resumed, and inactive are foreground (local, no FCM)', () {
      expect(peacockLifecycleIsForeground(null), isTrue);
      expect(peacockLifecycleIsForeground(AppLifecycleState.resumed), isTrue);
      expect(peacockLifecycleIsForeground(AppLifecycleState.inactive), isTrue);
    });

    test('paused, hidden, and detached are background (FCM, no local)', () {
      expect(peacockLifecycleIsForeground(AppLifecycleState.paused), isFalse);
      expect(peacockLifecycleIsForeground(AppLifecycleState.hidden), isFalse);
      expect(peacockLifecycleIsForeground(AppLifecycleState.detached), isFalse);
    });

    test('inactive Control Center plans local only — not FCM-to-self', () {
      final plan = planPeacockSelfNotify(
        notificationId: 'n1',
        currentUid: 'uid-1',
        isForeground: peacockLifecycleIsForeground(AppLifecycleState.inactive),
        locallyPresentedIds: {},
      );
      expect(plan.showLocal, isTrue);
      expect(plan.sendFcmToSelf, isFalse);
      expect(plan.recipientUids, isEmpty);
    });

    test('paused, hidden, and detached plan FCM only — not local', () {
      for (final state in [
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        final plan = planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'uid-1',
          isForeground: peacockLifecycleIsForeground(state),
          locallyPresentedIds: {},
        );
        expect(plan.showLocal, isFalse, reason: '$state');
        expect(plan.sendFcmToSelf, isTrue, reason: '$state');
        expect(plan.recipientUids, ['uid-1'], reason: '$state');
      }
    });
  });

  group('PeacockIdCache', () {
    test('evicts oldest when over maxSize', () {
      final cache = PeacockIdCache(
        maxSize: 2,
        clock: () => DateTime.utc(2026, 9, 2, 12),
      );
      cache.add('a');
      cache.add('b');
      cache.add('c');
      expect(cache.contains('a'), isFalse);
      expect(cache.contains('b'), isTrue);
      expect(cache.contains('c'), isTrue);
      expect(cache.length, 2);
    });

    test('drops entries older than ttl', () {
      var now = DateTime.utc(2026, 9, 2, 12);
      final cache = PeacockIdCache(
        maxSize: 8,
        ttl: const Duration(hours: 6),
        clock: () => now,
      );
      cache.add('old');
      now = now.add(const Duration(hours: 7));
      expect(cache.contains('old'), isFalse);
      expect(cache.length, 0);
    });

    test('clear empties the cache', () {
      final cache = PeacockIdCache(maxSize: 8);
      cache.add('a');
      cache.clear();
      expect(cache.contains('a'), isFalse);
      expect(cache.length, 0);
    });
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

    test('dispose clears tracked ids so the same id can be handled again',
        () async {
      final first = await runHandle(foreground: true);
      expect(first.local, isNotEmpty);
      expect(first.fcm, isEmpty);

      await PeacockNotificationService.dispose();

      final second = await runHandle(foreground: true);
      expect(second.local, isNotEmpty);
      expect(second.fcm, isEmpty);
      expect(second.sent, ['n1']);
    });

    test('handleNotification reduces assign+notifySelf on the tracker',
        () async {
      await runHandle(foreground: true);
      final state = PeacockAssignmentTracker.instance.stateFor('uid-1');
      expect(state.phase, PeacockAssignmentPhase.notified);
      expect(state.lobbyId, 'lobby-9');
      expect(state.gameName, 'Warzone');
      expect(state.notificationId, 'n1');
      expect(state.showedLocal, isTrue);
      expect(state.sentFcmToSelf, isFalse);
      expect(state.wouldDoubleNotifySelf, isFalse);
    });

    test('background handleNotification records FCM-to-self on the tracker',
        () async {
      await runHandle(foreground: false);
      final state = PeacockAssignmentTracker.instance.stateFor('uid-1');
      expect(state.phase, PeacockAssignmentPhase.notified);
      expect(state.showedLocal, isFalse);
      expect(state.sentFcmToSelf, isTrue);
      expect(state.wouldDoubleNotifySelf, isFalse);
    });
  });
}
