import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/fill_pin_nudge_audience.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE P2 — NUDGE WIRE (RED, Tester-owned).
///
/// [fillPinNudgeAudience] exists
/// (`lib/services/fill_pin_nudge_audience.dart`) but the live Fill PIN
/// "need one" path does not invoke it. Spot-open is still a stub
/// (`onSpotOpenNudge` / `shouldNudgeSpotOpen`) on Can't + Coming t=0.
///
/// This file is source-lease / import-call only. It fails until the
/// live caller wires the existing filter in. Do not invent a second
/// notify send pipeline. XOR stays [planPeacockSelfNotify].
/// Share-pin-not-chat stays queued.
///
/// Live "need one" caller (P2 lock-screen / Coming path):
/// - `lib/services/fill_pin_live_activity.dart`
///   [applyFillPinLiveActivityAction] (Can't) and
///   [tickFillPinComingHold] (t=0) fire the spot-open / "need one"
///   stub today. Those sites must call [fillPinNudgeAudience].
///
/// Loop lease (≤3 product files + pubspec on green — Tester does not
/// edit `lib/**` or bump pubspec; still 3.4.170+172 until Loop greens
/// → 3.4.171+173):
/// 1. `lib/services/fill_pin_live_activity.dart` — primary; import +
///    call [fillPinNudgeAudience] on the live Can't / expire nudge
/// 2. Optional: `lib/services/coming_hold_machine.dart` only if the
///    stub must pass stance UIDs through — keep ≤3
/// 3. Do not invent a new send file / pipeline. Reuse the existing
///    notify path. XOR stays [planPeacockSelfNotify].
///
/// Out of scope: chat_screen / chat_input_bar / chat_info_screen /
/// lobby_notifier dual-edit / Tonight-tab / AASA / GATES / merge /
/// share-pin-not-chat / full notify rewrite / pubspec bump (Tester).
const _kLiveNeedOneCaller = 'lib/services/fill_pin_live_activity.dart';
const _kAudienceFilter = 'lib/services/fill_pin_nudge_audience.dart';
const _kComingHold = 'lib/services/coming_hold_machine.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('live need-one caller invokes fillPinNudgeAudience', () {
    test('live Fill PIN caller file exists', () {
      expect(File(_kLiveNeedOneCaller).existsSync(), isTrue);
      expect(File(_kAudienceFilter).existsSync(), isTrue);
    });

    test(
      'live caller still fires the need-one / spot-open stub (Can\'t + t=0)',
      () {
        final src = _read(_kLiveNeedOneCaller);
        expect(src.contains('onSpotOpenNudge'), isTrue);
        expect(src.contains('applyFillPinLiveActivityAction'), isTrue);
        expect(src.contains('tickFillPinComingHold'), isTrue);
        expect(src.contains('FillPinLiveActivityAction.cant'), isTrue);
      },
    );

    test(
      'live need-one caller imports fill_pin_nudge_audience.dart',
      () {
        final src = _read(_kLiveNeedOneCaller);
        expect(
          src.contains('fill_pin_nudge_audience.dart'),
          isTrue,
          reason:
              'Loop lease: import fill_pin_nudge_audience.dart from '
              '$_kLiveNeedOneCaller so the live Can\'t / t=0 path can '
              'call fillPinNudgeAudience.',
        );
      },
    );

    test(
      'live need-one caller invokes fillPinNudgeAudience',
      () {
        final src = _read(_kLiveNeedOneCaller);
        expect(
          src.contains('fillPinNudgeAudience'),
          isTrue,
          reason:
              'App Tester + CoS: fillPinNudgeAudience exists but is not '
              'called from the live "need one" path. Wire the filter '
              'into $_kLiveNeedOneCaller (Can\'t / Coming t=0). Do not '
              'invent a new send pipeline.',
        );
      },
    );

    test(
      'Coming-hold stub is not a second notify pipeline',
      () {
        final hold = _read(_kComingHold);
        expect(hold.contains('onSpotOpenNudge'), isTrue);
        expect(hold.contains('sendNotificationToUsers'), isFalse);
        expect(hold.contains('FirebaseMessaging'), isFalse);
        expect(hold.contains('NotificationService'), isFalse);
      },
    );
  });

  group('filter stays UIDs only — XOR planPeacockSelfNotify', () {
    test('fillPinNudgeAudience is still the UID filter, not a send', () {
      final result = fillPinNudgeAudience(
        memberUids: const ['u1', 'u2', 'u3'],
        sitUids: const ['u1'],
        comingUids: const ['u2'],
      );
      expect(result.toSet(), {'u3'});
      expect(result, isA<Iterable<String>>());

      final filter = _read(_kAudienceFilter);
      expect(filter.contains('sendNotificationToUsers'), isFalse);
      expect(filter.contains('FirebaseMessaging'), isFalse);
      expect(filter.contains('NotificationService'), isFalse);
    });

    test('XOR stays planPeacockSelfNotify — no second self-notify path', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'u1',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );

      final live = _read(_kLiveNeedOneCaller);
      expect(live.contains('planPeacockSelfNotify'), isTrue);
      expect(live.contains('FirebaseMessaging'), isFalse);
    });
  });
}
