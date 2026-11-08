import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/fill_pin_visibility.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE P3B — PUBLIC SWITCH (RED, Tester-owned).
///
/// Pure-Dart group | public visibility for a Fill PIN. XOR flip only
/// (never both). Pin-scoped. Clear / end drops that pin's entry.
/// Default is group, not public. No chat UI. No Tonight. No second
/// notify pipeline.
///
/// Contract Loop must implement (leave RED until the product file
/// exists under `lib/services/`):
///
/// 1. Default visibility = [FillPinVisibility.group] (not public).
/// 2. [setFillPinVisibility] (`pinId`, public | group) flips XOR.
/// 3. Pin-scoped: pin A public does not make pin B public.
/// 4. Clear / end pin ([clearFillPinVisibilityOnEnd]) drops that
///    pin's visibility entry (resolve falls back to group).
/// 5. [resolveFillPinVisibility] (`pinId`) returns the visibility
///    for **that pin only**.
///
/// Loop lease (≤3 product files + pubspec on green — Tester does not
/// edit `lib/**` or bump pubspec):
/// 1. `lib/services/fill_pin_visibility.dart` (new; primary) —
///    [FillPinVisibility.group] / [FillPinVisibility.public],
///    [setFillPinVisibility], [resolveFillPinVisibility],
///    clear-on-end
///
/// XOR stays [planPeacockSelfNotify]. Do not invent a second notify
/// path in this file.
///
/// Out of scope: chat_screen / chat_input_bar / Tonight-tab / AASA /
/// GATES / merge / pubspec bump (Tester).
void main() {
  setUp(resetFillPinVisibilityStore);
  tearDown(resetFillPinVisibilityStore);

  group('default visibility is group (not public)', () {
    test('unset pin resolves to FillPinVisibility.group', () {
      expect(
        resolveFillPinVisibility('pin-1'),
        FillPinVisibility.group,
        reason: 'Default Fill PIN visibility must be group, not public.',
      );
      expect(
        resolveFillPinVisibility('pin-1'),
        isNot(FillPinVisibility.public),
      );
    });

    test('FillPinVisibility.group and public are XOR (never both)', () {
      expect(FillPinVisibility.group, isNot(FillPinVisibility.public));
      expect(identical(FillPinVisibility.group, FillPinVisibility.public), isFalse);
    });
  });

  group('setFillPinVisibility flips public | group XOR', () {
    test('setFillPinVisibility(pinId, public) flips to public', () {
      setFillPinVisibility('pin-1', FillPinVisibility.public);

      expect(resolveFillPinVisibility('pin-1'), FillPinVisibility.public);
      expect(
        resolveFillPinVisibility('pin-1'),
        isNot(FillPinVisibility.group),
        reason: 'Visibility is XOR: public unsets group.',
      );
    });

    test('setFillPinVisibility(pinId, group) flips public back to group', () {
      setFillPinVisibility('pin-1', FillPinVisibility.public);
      expect(resolveFillPinVisibility('pin-1'), FillPinVisibility.public);

      setFillPinVisibility('pin-1', FillPinVisibility.group);

      expect(resolveFillPinVisibility('pin-1'), FillPinVisibility.group);
      expect(
        resolveFillPinVisibility('pin-1'),
        isNot(FillPinVisibility.public),
        reason: 'Visibility is XOR: group unsets public.',
      );
    });
  });

  group('pin-scoped: pin A public does not make pin B public', () {
    test('resolveFillPinVisibility is pin-scoped — no cross-pin leak', () {
      setFillPinVisibility('pin-a', FillPinVisibility.public);

      expect(resolveFillPinVisibility('pin-a'), FillPinVisibility.public);
      expect(
        resolveFillPinVisibility('pin-b'),
        FillPinVisibility.group,
        reason: "Pin A public must not make pin B public.",
      );
      expect(resolveFillPinVisibility('pin-b'), isNot(FillPinVisibility.public));
    });

    test('each pin keeps its own XOR visibility', () {
      setFillPinVisibility('pin-a', FillPinVisibility.public);
      setFillPinVisibility('pin-b', FillPinVisibility.group);

      expect(resolveFillPinVisibility('pin-a'), FillPinVisibility.public);
      expect(resolveFillPinVisibility('pin-b'), FillPinVisibility.group);
    });
  });

  group('clear / end pin drops that pin\'s visibility entry', () {
    test('clearFillPinVisibilityOnEnd drops the entry (back to group)', () {
      setFillPinVisibility('pin-1', FillPinVisibility.public);
      expect(resolveFillPinVisibility('pin-1'), FillPinVisibility.public);

      clearFillPinVisibilityOnEnd('pin-1');

      expect(
        resolveFillPinVisibility('pin-1'),
        FillPinVisibility.group,
        reason: 'Clear / end must drop this pin\'s visibility entry.',
      );
      expect(resolveFillPinVisibility('pin-1'), isNot(FillPinVisibility.public));
    });

    test('clearing pin A does not drop pin B', () {
      setFillPinVisibility('pin-a', FillPinVisibility.public);
      setFillPinVisibility('pin-b', FillPinVisibility.public);

      clearFillPinVisibilityOnEnd('pin-a');

      expect(resolveFillPinVisibility('pin-a'), FillPinVisibility.group);
      expect(resolveFillPinVisibility('pin-b'), FillPinVisibility.public);
    });
  });

  group('XOR stays planPeacockSelfNotify — not a send pipeline', () {
    test('Loop lease file exposes group/public + set/resolve/clear-on-end', () {
      expect(File('lib/services/fill_pin_visibility.dart').existsSync(), isTrue);
      final src = File('lib/services/fill_pin_visibility.dart').readAsStringSync();
      expect(src.contains('FillPinVisibility'), isTrue);
      expect(src.contains('setFillPinVisibility'), isTrue);
      expect(src.contains('resolveFillPinVisibility'), isTrue);
      expect(src.contains('clearFillPinVisibilityOnEnd'), isTrue);
    });

    test('XOR stays planPeacockSelfNotify — visibility is not a send', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'u1',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );

      final src =
          File('lib/services/fill_pin_visibility.dart').readAsStringSync();
      expect(src.contains('sendNotificationToUsers'), isFalse);
      expect(src.contains('FirebaseMessaging'), isFalse);
      expect(src.contains('NotificationService'), isFalse);
    });
  });
}
