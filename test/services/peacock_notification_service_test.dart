import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';
import 'package:squad_sync/services/peacock_notification_service.dart';
import 'package:squad_sync/services/preferred_peacock_games.dart';

void main() {
  setUp(() {
    NotificationManager.showLocal = null;
    PeacockNotificationService.resetTestHooks();
  });

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

    test('re-adding the same event_id is idempotent', () {
      final cache = PeacockIdCache(maxSize: 8);
      cache.add('evt-1');
      cache.add('evt-1');
      expect(cache.contains('evt-1'), isTrue);
      expect(cache.length, 1);
    });
  });

  group('peacockEventId', () {
    test('prefers event_id over row id', () {
      expect(
        peacockEventId({
          'id': 'row-1',
          'event_id': 'evt-1',
          'data': {'event_id': 'nested-ignored', 'id': 'data-id'},
        }),
        'evt-1',
      );
    });

    test('falls back through notification_id then row id then data.id', () {
      expect(peacockEventId({'notification_id': 'n-1', 'id': 'row-1'}), 'n-1');
      expect(peacockEventId({'id': 'row-1'}), 'row-1');
      expect(
        peacockEventId({
          'data': {'event_id': 'from-data'},
        }),
        'from-data',
      );
      expect(
        peacockEventId({
          'data': {'id': 'data-id'},
        }),
        'data-id',
      );
      expect(peacockEventId(<String, dynamic>{}), isNull);
      expect(peacockEventId({'id': '  ', 'event_id': 'null'}), isNull);
    });
  });

  group('self-uid filter', () {
    test('peacockEventIsForCurrentUid skips another user', () {
      expect(
        peacockEventIsForCurrentUid(
          record: {'user_uid': 'other'},
          currentUid: 'me',
        ),
        isFalse,
      );
      expect(
        peacockEventIsForCurrentUid(
          record: {'user_uid': 'me'},
          currentUid: 'me',
        ),
        isTrue,
      );
      expect(
        peacockEventIsForCurrentUid(
          record: <String, dynamic>{},
          currentUid: 'me',
        ),
        isTrue,
      );
      expect(
        peacockEventIsForCurrentUid(
          record: {'user_uid': 'other'},
          currentUid: null,
        ),
        isTrue,
      );
    });

    test('peacockSelfUidRecipients never includes anyone but self', () {
      expect(
        peacockSelfUidRecipients(
          candidateUids: const ['me', 'u2', ' me ', 'me', ''],
          currentUid: 'me',
        ),
        ['me'],
      );
      expect(
        peacockSelfUidRecipients(
          candidateUids: const ['me', 'u2'],
          currentUid: 'me',
          showLocal: true,
        ),
        isEmpty,
      );
      expect(
        peacockSelfUidRecipients(
          candidateUids: const ['me'],
          currentUid: null,
        ),
        isEmpty,
      );
      expect(
        peacockSelfUidRecipients(
          candidateUids: const ['u2'],
          currentUid: 'me',
        ),
        isEmpty,
      );
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

    test('background self-uid filter drops blanks and other uids', () {
      final plan = planPeacockSelfNotify(
        notificationId: 'n1',
        currentUid: '  ',
        isForeground: false,
        locallyPresentedIds: {},
      );
      expect(plan.showLocal, isFalse);
      expect(plan.sendFcmToSelf, isFalse);
      expect(plan.recipientUids, isEmpty);
    });
  });

  group('handleNotification', () {
    Map<String, dynamic> record({
      String id = 'n1',
      String? eventId,
      String? userUid,
    }) =>
        {
          'id': id,
          if (eventId != null) 'event_id': eventId,
          if (userUid != null) 'user_uid': userUid,
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
          List<Map<String, dynamic>> fcmData,
          List<String> sent,
        })> runHandle({
      required bool foreground,
      String uid = 'uid-1',
      Map<String, dynamic>? payload,
    }) async {
      final local = <Map<String, dynamic>>[];
      final fcm = <List<String>>[];
      final fcmData = <Map<String, dynamic>>[];
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
        fcmData.add(Map<String, dynamic>.from(data ?? const {}));
      };
      PeacockNotificationService.markSentHook = (id) async {
        sent.add(id);
      };

      await PeacockNotificationService.handleNotification(
        payload ?? record(userUid: uid),
      );
      return (local: local, fcm: fcm, fcmData: fcmData, sent: sent);
    }

    bool xorHolds(
      List<Map<String, dynamic>> local,
      List<List<String>> fcm,
      String uid,
    ) {
      final fcmUids = fcm.expand((uids) => uids);
      return !(local.isNotEmpty && fcmUids.contains(uid));
    }

    test('skips notify when preferred games exclude the offer', () async {
      PreferredPeacockGamesStore.instance.games.add('MW2');
      final result = await runHandle(foreground: true);
      expect(result.local, isEmpty);
      expect(result.fcm, isEmpty);
      expect(result.sent, ['n1']);
      expect(
        PeacockAssignmentTracker.instance.stateFor('uid-1').phase,
        PeacockAssignmentPhase.assigned,
      );
    });

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

    test('missing event_id and row id is a no-op', () async {
      final result = await runHandle(
        foreground: true,
        payload: {
          'title': 'Spot ready',
          'body': 'Your peacock queue assigned a lobby',
          'data': {'type': 'peacock_assigned'},
        },
      );
      expect(result.local, isEmpty);
      expect(result.fcm, isEmpty);
      expect(result.sent, isEmpty);
    });

    test('same event_id is idempotent even when the row id differs', () async {
      final first = await runHandle(
        foreground: true,
        payload: record(id: 'row-1', eventId: 'evt-1', userUid: 'uid-1'),
      );
      expect(first.local, isNotEmpty);
      expect(first.local.first['event_id'], 'evt-1');
      expect(first.fcm, isEmpty);
      expect(first.sent, ['row-1']);

      final second = await runHandle(
        foreground: false,
        payload: record(id: 'row-2', eventId: 'evt-1', userUid: 'uid-1'),
      );
      expect(second.local, isEmpty);
      expect(second.fcm, isEmpty);
      expect(second.sent, ['row-2']);
    });

    test('event_id in data matches row id for cache identity', () async {
      final first = await runHandle(
        foreground: true,
        payload: {
          'id': 'evt-1',
          'user_uid': 'uid-1',
          'title': 'Spot ready',
          'body': 'Your peacock queue assigned a lobby',
          'data': {
            'type': 'peacock_assigned',
            'lobby_id': 'lobby-9',
            'game_name': 'Warzone',
          },
        },
      );
      expect(first.local, isNotEmpty);

      final second = await runHandle(
        foreground: false,
        payload: {
          'id': 'row-2',
          'user_uid': 'uid-1',
          'title': 'Spot ready',
          'body': 'Your peacock queue assigned a lobby',
          'data': {
            'type': 'peacock_assigned',
            'event_id': 'evt-1',
            'lobby_id': 'lobby-9',
          },
        },
      );
      expect(second.local, isEmpty);
      expect(second.fcm, isEmpty);
    });

    test('distinct event_ids notify independently without mixing XOR',
        () async {
      final first = await runHandle(
        foreground: true,
        payload: record(id: 'a', eventId: 'evt-a', userUid: 'uid-1'),
      );
      final second = await runHandle(
        foreground: false,
        payload: record(id: 'b', eventId: 'evt-b', userUid: 'uid-1'),
      );
      expect(first.local, isNotEmpty);
      expect(first.fcm, isEmpty);
      expect(second.local, isEmpty);
      expect(second.fcm, [
        ['uid-1']
      ]);
      expect(second.fcmData.first['event_id'], 'evt-b');
      expect(xorHolds(first.local, first.fcm, 'uid-1'), isTrue);
      expect(xorHolds(second.local, second.fcm, 'uid-1'), isTrue);
    });

    test('record for another uid is not presented locally or via FCM',
        () async {
      final result = await runHandle(
        foreground: true,
        uid: 'me',
        payload: record(id: 'n1', userUid: 'other'),
      );
      expect(result.local, isEmpty);
      expect(result.fcm, isEmpty);
      expect(result.sent, ['n1']);
    });

    test('background FCM recipients are only the current uid', () async {
      final result = await runHandle(foreground: false);
      expect(result.local, isEmpty);
      expect(result.fcm, [
        ['uid-1']
      ]);
      expect(result.fcmData.first['event_id'], 'n1');
      expect(result.fcmData.first['type'], 'peacock_assigned');
    });

    test('foreground Realtime vs background FCM follows lifecycle', () async {
      const foregroundStates = [
        null,
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
      ];
      const backgroundStates = [
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ];

      for (final state in foregroundStates) {
        PeacockNotificationService.resetTestHooks();
        NotificationManager.showLocal = null;
        PeacockNotificationService.isForegroundHook = null;
        final result = await runHandle(
          foreground: peacockLifecycleIsForeground(state),
        );
        expect(result.local, isNotEmpty, reason: '$state');
        expect(result.fcm, isEmpty, reason: '$state');
        expect(xorHolds(result.local, result.fcm, 'uid-1'), isTrue);
      }

      for (final state in backgroundStates) {
        PeacockNotificationService.resetTestHooks();
        NotificationManager.showLocal = null;
        final result = await runHandle(
          foreground: peacockLifecycleIsForeground(state),
        );
        expect(result.local, isEmpty, reason: '$state');
        expect(
            result.fcm,
            [
              ['uid-1']
            ],
            reason: '$state');
        expect(xorHolds(result.local, result.fcm, 'uid-1'), isTrue);
      }
    });

    test('same event_id never both in-app and FCM across FG then BG', () async {
      final local = await runHandle(foreground: true);
      expect(local.local, isNotEmpty);
      expect(local.fcm, isEmpty);

      final fcm = await runHandle(foreground: false);
      expect(fcm.local, isEmpty);
      expect(fcm.fcm, isEmpty);

      final combinedLocal = [...local.local, ...fcm.local];
      final combinedFcm = [...local.fcm, ...fcm.fcm];
      expect(xorHolds(combinedLocal, combinedFcm, 'uid-1'), isTrue);
    });

    test('same event_id never both in-app and FCM across BG then FG', () async {
      final fcm = await runHandle(foreground: false);
      expect(fcm.local, isEmpty);
      expect(fcm.fcm, isNotEmpty);

      final local = await runHandle(foreground: true);
      expect(local.local, isEmpty);
      expect(local.fcm, isEmpty);

      final combinedLocal = [...fcm.local, ...local.local];
      final combinedFcm = [...fcm.fcm, ...local.fcm];
      expect(xorHolds(combinedLocal, combinedFcm, 'uid-1'), isTrue);
    });

    test('XOR pack: every lifecycle × already-local pair is one channel',
        () async {
      const uid = 'uid-1';
      for (final state in AppLifecycleState.values) {
        for (final already in [false, true]) {
          PeacockNotificationService.resetTestHooks();
          NotificationManager.showLocal = null;
          if (already) {
            final first = await runHandle(
              foreground: true,
              payload: record(id: 'n1', userUid: uid),
            );
            expect(first.local, isNotEmpty);
          }
          final result = await runHandle(
            foreground: peacockLifecycleIsForeground(state),
            payload: record(id: 'n1', userUid: uid),
          );
          expect(
            xorHolds(result.local, result.fcm, uid),
            isTrue,
            reason: '$state already=$already',
          );
          if (already) {
            expect(result.local, isEmpty, reason: '$state replay');
            expect(result.fcm, isEmpty, reason: '$state replay');
          }
        }
      }
    });
  });
}
