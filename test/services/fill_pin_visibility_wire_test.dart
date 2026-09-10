import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/fill_pin_visibility.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE P3B-wire — PUBLIC SWITCH LIVE CALLER (RED, Tester-owned).
///
/// [setFillPinVisibility] / [resolveFillPinVisibility] exist
/// (`lib/services/fill_pin_visibility.dart`; units CLOSED) but the
/// live Fill PIN path does not invoke them. App Tester: WIRED no.
///
/// This file is source-lease / import-call only. It fails until the
/// live caller wires the existing group | public XOR in. Do not
/// invent a second notify send pipeline. XOR stays
/// [planPeacockSelfNotify].
///
/// Live public-switch caller (create/update or pin header):
/// - `lib/chat/fill_pin_thread_header.dart`
///   [FillPinThreadHeader] is the friend-visible pin header (game +
///   n/max + Share). That site must import + call
///   [setFillPinVisibility] and/or [resolveFillPinVisibility] so the
///   public switch on that pin is group XOR public. Pin-scoped.
///   Default remains group.
///
/// Loop lease (≤3 product files + pubspec on green — Tester does not
/// edit `lib/**` or bump pubspec; still 3.4.175+177 until Loop greens):
/// 1. `lib/chat/fill_pin_thread_header.dart` — primary; import +
///    call [setFillPinVisibility] and/or [resolveFillPinVisibility]
///    on the live pin header public switch
/// 2. Optional: `lib/chat/fill_pin_group_row_badge.dart` only if the
///    My Groups badge must resolve visibility — keep ≤3
/// 3. Optional: `lib/services/fill_pin_live_activity.dart` only if
///    pin end must call [clearFillPinVisibilityOnEnd]
///
/// Never dual-edit `lobby_notifier.dart`. Do not invent a new
/// visibility store / pipeline.
///
/// Out of scope: chat_screen / chat_input_bar / chat_info_screen /
/// lobby_notifier dual-edit / Tonight-tab / AASA / GATES / merge /
/// P3C link-preview / pubspec bump (Tester).
const _kLiveVisibilityCaller = 'lib/chat/fill_pin_thread_header.dart';
const _kVisibility = 'lib/services/fill_pin_visibility.dart';
const _kGroupRowBadge = 'lib/chat/fill_pin_group_row_badge.dart';
const _kLobbyNotifier = 'lib/presentation/notifiers/lobby_notifier.dart';

String _read(String path) => File(path).readAsStringSync();

bool _callsSetOrResolve(String src) {
  return src.contains('setFillPinVisibility') ||
      src.contains('resolveFillPinVisibility');
}

void main() {
  setUp(resetFillPinVisibilityStore);
  tearDown(resetFillPinVisibilityStore);

  group('live pin-header caller invokes fill pin visibility', () {
    test('live Fill PIN caller file exists', () {
      expect(File(_kLiveVisibilityCaller).existsSync(), isTrue);
      expect(File(_kVisibility).existsSync(), isTrue);
      expect(File(_kGroupRowBadge).existsSync(), isTrue);
    });

    test(
      'live caller is still the pin header (create/update surface)',
      () {
        final src = _read(_kLiveVisibilityCaller);
        expect(src.contains('FillPinThreadHeader'), isTrue);
        expect(src.contains('resolveFillPinForThread'), isTrue);
        expect(src.contains('kFillPinThreadHeaderKey'), isTrue);
        expect(src.contains('kFillPinShareKey'), isTrue);
      },
    );

    test(
      'live pin-header caller imports fill_pin_visibility.dart',
      () {
        final src = _read(_kLiveVisibilityCaller);
        expect(
          src.contains('fill_pin_visibility.dart'),
          isTrue,
          reason:
              'Loop lease: import fill_pin_visibility.dart from '
              '$_kLiveVisibilityCaller so the live pin header can '
              'call setFillPinVisibility and/or '
              'resolveFillPinVisibility.',
        );
      },
    );

    test(
      'live pin-header caller invokes setFillPinVisibility '
      'and/or resolveFillPinVisibility',
      () {
        final src = _read(_kLiveVisibilityCaller);
        expect(
          _callsSetOrResolve(src),
          isTrue,
          reason:
              'App Tester + CoS: setFillPinVisibility / '
              'resolveFillPinVisibility exist but are not called '
              'from the live pin path. Wire the public switch into '
              '$_kLiveVisibilityCaller (group XOR public, pin-scoped, '
              'default group). Do not invent a new visibility store.',
        );
      },
    );

    test(
      'lobby_notifier is not the visibility lease (no dual-edit)',
      () {
        final notifier = _read(_kLobbyNotifier);
        expect(notifier.contains('fill_pin_visibility.dart'), isFalse);
        expect(notifier.contains('setFillPinVisibility'), isFalse);
        expect(notifier.contains('resolveFillPinVisibility'), isFalse);
      },
    );
  });

  group('switch stays pin-scoped group XOR public — XOR planPeacockSelfNotify',
      () {
    test('default remains group; set/resolve stay pin-scoped XOR', () {
      expect(
        resolveFillPinVisibility('pin-1'),
        FillPinVisibility.group,
      );
      expect(
        resolveFillPinVisibility('pin-1'),
        isNot(FillPinVisibility.public),
      );

      setFillPinVisibility('pin-a', FillPinVisibility.public);
      expect(resolveFillPinVisibility('pin-a'), FillPinVisibility.public);
      expect(resolveFillPinVisibility('pin-b'), FillPinVisibility.group);

      final store = _read(_kVisibility);
      expect(store.contains('sendNotificationToUsers'), isFalse);
      expect(store.contains('FirebaseMessaging'), isFalse);
      expect(store.contains('NotificationService'), isFalse);
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

      final live = _read(_kLiveVisibilityCaller);
      expect(live.contains('sendNotificationToUsers'), isFalse);
      expect(live.contains('FirebaseMessaging'), isFalse);
      expect(live.contains('NotificationService'), isFalse);
    });
  });
}
