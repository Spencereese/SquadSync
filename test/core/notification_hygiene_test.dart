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
  });

  test('formatMinutes pads hours and minutes', () {
    expect(NotificationHygiene.formatMinutes(22 * 60), '22:00');
    expect(NotificationHygiene.formatMinutes(8 * 60 + 5), '08:05');
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
  });
}
