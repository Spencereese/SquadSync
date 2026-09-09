import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/fill_pin_link_preview.dart';

/// PIN WAVE P3C — LINK PREVIEW TITLE (RED, Tester-owned).
///
/// Pure-Dart Fill PIN OG / share title. Game + seated/max + sit-here
/// suffix. Middle dot is Unicode `·` (U+00B7), not ASCII period /
/// bullet. No chat UI. No Tonight. No AASA / GATES.
///
/// Contract Loop must implement (leave RED until the product file
/// exists under `lib/services/`):
///
/// ```
/// String fillPinLinkPreviewTitle({
///   required String game,
///   required int seated,
///   required int max,
/// }) => "$game $seated/$max · sit here";
/// ```
///
/// Happy path: game=`Warzone`, seated=`2`, max=`4` →
/// `Warzone 2/4 · sit here`.
///
/// Adversarial edges (chosen, implementable, do not throw):
///
/// 1. Blank / whitespace-only [game] → trim. If empty after trim,
///    keep a literal empty game segment:
///    ` $seated/$max · sit here` (leading space). No `Game` /
///    `Fill PIN` fallback.
/// 2. Non-empty [game] is trimmed before format
///    (`  Warzone  ` → `Warzone 2/4 · sit here`).
/// 3. [seated] > [max] → format literally (`Warzone 5/4 · sit here`).
///    No clamp.
/// 4. [seated] < 0 → clamp seated to `max(0, seated)`; leave [max]
///    as given (`Warzone 0/4 · sit here`).
/// 5. Title always contains Unicode middle dot `·` (U+00B7).
///
/// Optional cheap wire (same file; no second RED): once the helper
/// exists, `lib/services/fill_pin_share.dart`
/// ([fillPinSharePreviewTitle] / payload builder) must import +
/// call [fillPinLinkPreviewTitle]. That share stub already formats
/// the same shape and comments that P3 link-preview can reuse it.
///
/// Loop lease (≤3 product files + pubspec on green — Tester does not
/// edit `lib/**` or bump pubspec):
/// 1. `lib/services/fill_pin_link_preview.dart` (new; primary) —
///    [fillPinLinkPreviewTitle]
/// 2. Optional one-line share wire:
///    `lib/services/fill_pin_share.dart` import + call from
///    [fillPinSharePreviewTitle]
/// 3. pubspec bump only when Loop greens
///
/// Out of scope: chat_screen / chat_input_bar / Tonight-tab / AASA /
/// GATES / merge / lobby_notifier / pubspec bump (Tester).
const _kHelper = 'lib/services/fill_pin_link_preview.dart';
const _kShare = 'lib/services/fill_pin_share.dart';
const _kMiddleDot = '·';

void main() {
  group('fillPinLinkPreviewTitle happy path', () {
    test('Warzone 2/4 · sit here', () {
      expect(
        fillPinLinkPreviewTitle(game: 'Warzone', seated: 2, max: 4),
        'Warzone 2/4 · sit here',
      );
    });

    test('title contains Unicode middle dot U+00B7', () {
      final title = fillPinLinkPreviewTitle(
        game: 'Warzone',
        seated: 2,
        max: 4,
      );
      expect(title, contains(_kMiddleDot));
      expect(title.contains('.'), isFalse);
      expect(title.codeUnits, contains(0x00B7));
    });
  });

  group('blank / whitespace game — trim, empty segment, no throw', () {
    test('whitespace-only game formats as " \$seated/\$max · sit here"', () {
      expect(
        fillPinLinkPreviewTitle(game: '   ', seated: 2, max: 4),
        ' 2/4 · sit here',
      );
    });

    test('empty game keeps the leading space before seated/max', () {
      expect(
        fillPinLinkPreviewTitle(game: '', seated: 1, max: 4),
        ' 1/4 · sit here',
      );
    });

    test('non-empty game is trimmed before format', () {
      expect(
        fillPinLinkPreviewTitle(game: '  Warzone  ', seated: 2, max: 4),
        'Warzone 2/4 · sit here',
      );
    });
  });

  group('seated vs max — literal overflow, clamp negative seated', () {
    test('seated > max formats literally (no clamp)', () {
      expect(
        fillPinLinkPreviewTitle(game: 'Warzone', seated: 5, max: 4),
        'Warzone 5/4 · sit here',
      );
    });

    test('seated < 0 clamps seated to max(0, seated); max stays given', () {
      expect(
        fillPinLinkPreviewTitle(game: 'Warzone', seated: -1, max: 4),
        'Warzone 0/4 · sit here',
      );
      expect(
        fillPinLinkPreviewTitle(game: 'Warzone', seated: -3, max: 6),
        'Warzone 0/6 · sit here',
      );
    });
  });

  group('lease file + optional share wire', () {
    test('lib/services/fill_pin_link_preview.dart exists once green', () {
      expect(File(_kHelper).existsSync(), isTrue);
      final src = File(_kHelper).readAsStringSync();
      expect(src.contains('fillPinLinkPreviewTitle'), isTrue);
    });

    test(
      'fill_pin_share.dart imports + calls fillPinLinkPreviewTitle',
      () {
        expect(File(_kShare).existsSync(), isTrue);
        final src = File(_kShare).readAsStringSync();
        expect(
          src.contains('fill_pin_link_preview.dart'),
          isTrue,
          reason:
              'Optional Loop wire: import fill_pin_link_preview.dart '
              'from $_kShare so fillPinSharePreviewTitle / payload '
              'reuses fillPinLinkPreviewTitle.',
        );
        expect(
          src.contains('fillPinLinkPreviewTitle'),
          isTrue,
          reason:
              'Optional Loop wire: call fillPinLinkPreviewTitle from '
              'the existing share preview / payload builder.',
        );
      },
    );
  });
}
