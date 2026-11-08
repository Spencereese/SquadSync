import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/core/notification_hygiene.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

void main() {
  final overnight = const NotificationHygieneSnapshot(
    mutedSquadIds: {},
    quietHoursEnabled: true,
    startMinutes: 22 * 60,
    endMinutes: 8 * 60,
  );

  group('isInQuietHours', () {
    test('disabled never suppresses', () {
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: false,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 23),
        ),
        isFalse,
      );
    });

    test('overnight window includes start and excludes end', () {
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 22),
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 23, 30),
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 7, 59),
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 8),
        ),
        isFalse,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 12),
        ),
        isFalse,
      );
    });

    test('same-day window is start inclusive and end exclusive', () {
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 9 * 60,
          endMinutes: 17 * 60,
          now: DateTime(2026, 1, 1, 9),
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 9 * 60,
          endMinutes: 17 * 60,
          now: DateTime(2026, 1, 1, 16, 59),
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 9 * 60,
          endMinutes: 17 * 60,
          now: DateTime(2026, 1, 1, 17),
        ),
        isFalse,
      );
    });

    test('equal start and end is not a window', () {
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 12 * 60,
          endMinutes: 12 * 60,
          now: DateTime(2026, 1, 1, 12),
        ),
        isFalse,
      );
    });

    test('toggle off while quiet window active immediately resumes', () {
      final now = DateTime(2026, 1, 1, 23, 15);
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: now,
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: false,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: now,
        ),
        isFalse,
      );
      const on = NotificationHygieneSnapshot(
        mutedSquadIds: {},
        quietHoursEnabled: true,
        startMinutes: 22 * 60,
        endMinutes: 8 * 60,
      );
      const off = NotificationHygieneSnapshot(
        mutedSquadIds: {},
        quietHoursEnabled: false,
        startMinutes: 22 * 60,
        endMinutes: 8 * 60,
      );
      const payload = {'type': 'availability_ping', 'lobby_id': 'lobby-9'};
      expect(
        NotificationHygiene.shouldSuppressShow(
          payload: payload,
          settings: on,
          now: now,
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.shouldSuppressShow(
          payload: payload,
          settings: off,
          now: now,
        ),
        isFalse,
      );
      expect(
        NotificationHygiene.recipientsAfterHygiene(
          recipientUids: const ['u2'],
          payload: payload,
          settings: on,
          now: now,
        ),
        isEmpty,
      );
      expect(
        NotificationHygiene.recipientsAfterHygiene(
          recipientUids: const ['u2'],
          payload: payload,
          settings: off,
          now: now,
        ),
        ['u2'],
      );
    });

    test('midnight wrap includes 00:00 and 23:59 and excludes end', () {
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 2, 0),
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 23, 59),
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 2, 8),
        ),
        isFalse,
      );
    });

    test('window ending at midnight excludes 00:00', () {
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 0,
          now: DateTime(2026, 1, 1, 23, 59),
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 0,
          now: DateTime(2026, 1, 2, 0),
        ),
        isFalse,
      );
    });

    test('window starting at midnight includes 00:00', () {
      expect(
        isOvernightQuietWindow(0, 8 * 60),
        isFalse,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 0,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 0),
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 0,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 8),
        ),
        isFalse,
      );
    });

    test('overflow and negative minutes wrap the day', () {
      expect(NotificationHygiene.clampMinutes(25 * 60), 60);
      expect(NotificationHygiene.clampMinutes(-1), (24 * 60) - 1);
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 25 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 1),
        ),
        isTrue,
      );
      expect(NotificationHygiene.formatMinutes(-1), '23:59');
      expect(NotificationHygiene.formatMinutes(24 * 60), '00:00');
    });
  });

  group('mute this squad', () {
    test('payload ids match lobby, squad, and chat group keys', () {
      expect(
        NotificationHygiene.idsInPayload({
          'lobby_id': 'lobby-9',
          'squad_id': 'squad-1',
          'chat_group_id': 'g1',
        }),
        {'lobby-9', 'squad-1', 'g1'},
      );
    });

    test('muted squad suppresses local show', () {
      const settings = NotificationHygieneSnapshot(
        mutedSquadIds: {'squad-1', 'lobby-9'},
        quietHoursEnabled: false,
        startMinutes: NotificationHygiene.defaultStartMinutes,
        endMinutes: NotificationHygiene.defaultEndMinutes,
      );
      expect(
        NotificationHygiene.shouldSuppressShow(
          payload: {'type': 'availability_ping', 'lobby_id': 'lobby-9'},
          settings: settings,
        ),
        isTrue,
      );
      expect(
        NotificationHygiene.shouldSuppressShow(
          payload: {'type': 'peacock_assigned', 'lobby_id': 'other'},
          settings: settings,
        ),
        isFalse,
      );
    });
  });

  group('send path', () {
    test('quiet hours suppress every recipient', () {
      expect(
        NotificationHygiene.recipientsAfterHygiene(
          recipientUids: const ['u2', 'u3'],
          payload: const {'type': 'availability_ping', 'lobby_id': 'lobby-9'},
          settings: overnight,
          currentUid: 'u1',
          now: DateTime(2026, 1, 1, 23),
        ),
        isEmpty,
      );
    });

    test('outside quiet hours send is unchanged', () {
      expect(
        NotificationHygiene.recipientsAfterHygiene(
          recipientUids: const ['u2', 'u3'],
          payload: const {'type': 'availability_ping', 'lobby_id': 'lobby-9'},
          settings: overnight,
          currentUid: 'u1',
          now: DateTime(2026, 1, 1, 12),
        ),
        ['u2', 'u3'],
      );
    });

    test('muted squad drops self only so teammates still get the send', () {
      const settings = NotificationHygieneSnapshot(
        mutedSquadIds: {'lobby-9'},
        quietHoursEnabled: false,
        startMinutes: NotificationHygiene.defaultStartMinutes,
        endMinutes: NotificationHygiene.defaultEndMinutes,
      );
      expect(
        NotificationHygiene.recipientsAfterHygiene(
          recipientUids: const ['me', 'u2'],
          payload: const {'type': 'peacock_assigned', 'lobby_id': 'lobby-9'},
          settings: settings,
          currentUid: 'me',
        ),
        ['u2'],
      );
    });

    test('self-uid filter on muted send drops duplicates of self', () {
      const settings = NotificationHygieneSnapshot(
        mutedSquadIds: {'lobby-9'},
        quietHoursEnabled: false,
        startMinutes: NotificationHygiene.defaultStartMinutes,
        endMinutes: NotificationHygiene.defaultEndMinutes,
      );
      expect(
        NotificationHygiene.recipientsAfterHygiene(
          recipientUids: const ['me', 'u2', 'me', 'u3'],
          payload: const {'type': 'peacock_assigned', 'lobby_id': 'lobby-9'},
          settings: settings,
          currentUid: 'me',
        ),
        ['u2', 'u3'],
      );
    });

    test('muted send without currentUid does not invent a self drop', () {
      const settings = NotificationHygieneSnapshot(
        mutedSquadIds: {'lobby-9'},
        quietHoursEnabled: false,
        startMinutes: NotificationHygiene.defaultStartMinutes,
        endMinutes: NotificationHygiene.defaultEndMinutes,
      );
      expect(
        NotificationHygiene.recipientsAfterHygiene(
          recipientUids: const ['me', 'u2'],
          payload: const {'type': 'peacock_assigned', 'lobby_id': 'lobby-9'},
          settings: settings,
          currentUid: null,
        ),
        ['me', 'u2'],
      );
      expect(
        NotificationHygiene.recipientsAfterHygiene(
          recipientUids: const ['me', 'u2'],
          payload: const {'type': 'peacock_assigned', 'lobby_id': 'lobby-9'},
          settings: settings,
          currentUid: '  ',
        ),
        ['me', 'u2'],
      );
    });
  });

  test('hygiene does not add a second peacock presenter (XOR still holds)', () {
    expect(
      planPeacockSelfNotify(
        notificationId: 'n1',
        currentUid: 'me',
        isForeground: true,
        locallyPresentedIds: {},
      ).wouldDoubleNotifySelf,
      isFalse,
    );
    expect(
      planPeacockSelfNotify(
        notificationId: 'n1',
        currentUid: 'me',
        isForeground: false,
        locallyPresentedIds: {},
      ).wouldDoubleNotifySelf,
      isFalse,
    );
    final alreadyLocal = planPeacockSelfNotify(
      notificationId: 'evt-1',
      currentUid: 'me',
      isForeground: false,
      locallyPresentedIds: {'evt-1'},
    );
    expect(alreadyLocal.showLocal, isFalse);
    expect(alreadyLocal.sendFcmToSelf, isFalse);
    expect(alreadyLocal.wouldDoubleNotifySelf, isFalse);
  });

  test('formatMinutes pads hours and minutes', () {
    expect(NotificationHygiene.formatMinutes(22 * 60), '22:00');
    expect(NotificationHygiene.formatMinutes(8 * 60 + 5), '08:05');
  });

  group('quiet hours mapper / rules', () {
    test('empty schedule is not a window even when enabled', () {
      expect(hasQuietWindow(12 * 60, 12 * 60), isFalse);
      expect(hasQuietWindow(24 * 60, 0), isFalse);
      expect(hasQuietWindow(22 * 60, 8 * 60), isTrue);
      expect(
        resolveQuietHoursPhase(
          enabled: true,
          startMinutes: 12 * 60,
          endMinutes: 12 * 60,
        ),
        QuietHoursPhase.emptySchedule,
      );
      expect(
        NotificationHygiene.isInQuietHours(
          enabled: true,
          startMinutes: 12 * 60,
          endMinutes: 12 * 60,
          now: DateTime(2026, 1, 1, 12),
        ),
        isFalse,
      );
      const emptySchedule = NotificationHygieneSnapshot(
        mutedSquadIds: {},
        quietHoursEnabled: true,
        startMinutes: 12 * 60,
        endMinutes: 12 * 60,
      );
      expect(
        NotificationHygiene.shouldSuppressShow(
          payload: const {'type': 'availability_ping', 'lobby_id': 'lobby-9'},
          settings: emptySchedule,
          now: DateTime(2026, 1, 1, 12),
        ),
        isFalse,
      );
    });

    test('overnight window label and same-day window label', () {
      expect(isOvernightQuietWindow(22 * 60, 8 * 60), isTrue);
      expect(isOvernightQuietWindow(9 * 60, 17 * 60), isFalse);
      expect(
        quietHoursWindowLabel(22 * 60, 8 * 60),
        '22:00 – 08:00 overnight',
      );
      expect(quietHoursWindowLabel(9 * 60, 17 * 60), '09:00 – 17:00');
    });

    test('phase and copy for off / on / active-now / empty / error', () {
      expect(
        resolveQuietHoursPhase(
          enabled: false,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
        ),
        QuietHoursPhase.off,
      );
      expect(
        quietHoursMessage(
          phase: QuietHoursPhase.off,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
        ),
        'Off — pause all notification sends 22:00 – 08:00 overnight',
      );
      expect(
        quietHoursMessage(
          phase: QuietHoursPhase.on,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
        ),
        'Pausing all notification sends 22:00 – 08:00 overnight',
      );
      expect(
        quietHoursMessage(
          phase: QuietHoursPhase.on,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          activeNow: true,
        ),
        'Pausing now through 08:00. $kQuietHoursActiveNowHint',
      );
      expect(
        quietHoursMessage(
          phase: QuietHoursPhase.emptySchedule,
          startMinutes: 12 * 60,
          endMinutes: 12 * 60,
        ),
        kQuietHoursEmptyScheduleCopy,
      );
      expect(
        quietHoursHint(QuietHoursPhase.emptySchedule),
        kQuietHoursEmptyScheduleHint,
      );
      expect(
        resolveQuietHoursPhase(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          error: 'offline',
        ),
        QuietHoursPhase.error,
      );
      expect(
        quietHoursMessage(
          phase: QuietHoursPhase.error,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
        ),
        kQuietHoursErrorCopy,
      );
      expect(quietHoursHint(QuietHoursPhase.error), kQuietHoursErrorHint);
      expect(
        quietHoursMessage(
          phase: QuietHoursPhase.off,
          startMinutes: 12 * 60,
          endMinutes: 12 * 60,
        ),
        kQuietHoursOffEmptyWindowCopy,
      );
    });

    test('mute phase copy and error', () {
      expect(
        resolveMuteThisSquadPhase(muted: false),
        MuteThisSquadPhase.off,
      );
      expect(
        muteThisSquadMessage(MuteThisSquadPhase.off),
        kMuteThisSquadEmptyCopy,
      );
      expect(
        resolveMuteThisSquadPhase(muted: true),
        MuteThisSquadPhase.on,
      );
      expect(
        muteThisSquadMessage(MuteThisSquadPhase.on),
        kMuteThisSquadOnCopy,
      );
      expect(
        resolveMuteThisSquadPhase(muted: true, error: 'denied'),
        MuteThisSquadPhase.error,
      );
      expect(
        muteThisSquadMessage(MuteThisSquadPhase.error),
        kMuteThisSquadErrorCopy,
      );
      expect(
        muteThisSquadHint(MuteThisSquadPhase.error),
        kMuteThisSquadErrorHint,
      );
    });
  });

  group('hygiene persist mapper', () {
    test('thrown persist is error', () async {
      final result = await runHygienePersist(
        () async => throw Exception('offline'),
      );
      expect(result.isOk, isFalse);
      expect(hygieneErrorDetail(result.error), 'offline');
    });

    test('retry re-runs persist and can succeed', () async {
      var calls = 0;
      Future<void> persist() async {
        calls++;
        if (calls == 1) throw Exception('offline');
      }

      final first = await runHygienePersist(persist);
      expect(first.isOk, isFalse);
      expect(calls, 1);

      final second = await retryHygienePersist(persist);
      expect(second.isOk, isTrue);
      expect(calls, 2);
    });

    test('retry after error can stay error', () async {
      Future<void> persist() async => throw Exception('denied');
      final first = await runHygienePersist(persist);
      final second = await retryHygienePersist(persist);
      expect(first.isOk, isFalse);
      expect(second.isOk, isFalse);
      expect(hygieneErrorDetail(second.error), 'denied');
    });
  });

  group('NotificationHygieneStore', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      NotificationHygieneStore.instance.reset();
    });

    test('setSquadMuted stores aliases used by lobby and chat payloads',
        () async {
      final store = NotificationHygieneStore();
      await store.setSquadMuted('squad-1', true, aliases: ['lobby-9', 'g1']);
      expect(store.isSquadIdMuted('squad-1'), isTrue);
      expect(store.isSquadIdMuted('lobby-9'), isTrue);
      expect(store.isSquadIdMuted('g1'), isTrue);
      expect(
        store.shouldSuppressShow({'lobby_id': 'lobby-9', 'type': 'chat'}),
        isTrue,
      );
    });

    test('recipientsForSend is the live send wrapper', () {
      final store = NotificationHygieneStore(
        clock: () => DateTime(2026, 1, 1, 23),
      );
      store.quietHoursEnabled = true;
      expect(
        store.recipientsForSend(
          recipientUids: const ['u2'],
          data: const {'type': 'availability_ping', 'lobby_id': 'lobby-9'},
        ),
        isEmpty,
      );
    });

    test('setQuietHours toggle off while window active resumes now', () async {
      final store = NotificationHygieneStore(
        clock: () => DateTime(2026, 1, 1, 23),
      );
      await store.setQuietHours(
        enabled: true,
        startMinutes: 22 * 60,
        endMinutes: 8 * 60,
      );
      expect(
        store.shouldSuppressShow(
          const {'type': 'availability_ping', 'lobby_id': 'lobby-9'},
        ),
        isTrue,
      );
      await store.setQuietHours(enabled: false);
      expect(
        store.shouldSuppressShow(
          const {'type': 'availability_ping', 'lobby_id': 'lobby-9'},
        ),
        isFalse,
      );
    });

    test('empty schedule never suppresses even when enabled', () async {
      final store = NotificationHygieneStore(
        clock: () => DateTime(2026, 1, 1, 12),
      );
      await store.setQuietHours(
        enabled: true,
        startMinutes: 12 * 60,
        endMinutes: 12 * 60,
      );
      expect(
        store.shouldSuppressShow(
          const {'type': 'availability_ping', 'lobby_id': 'lobby-9'},
        ),
        isFalse,
      );
    });
  });
}
