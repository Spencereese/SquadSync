import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/fill_pin_suggestion_parser.dart';
import 'package:squad_sync/core/party_size_map.dart';

/// PIN WAVE — Slice P0 PARSER+CHIP CONTRACT (RED, Tester-owned).
///
/// Pure-Dart Fill PIN suggestion parser. Chip **UI** is a later Build
/// slice — this file locks output shape + trigger rules only.
///
/// Contract Loop must implement (do not invent a second parser):
///
/// 1. [parseFillPinSuggestion] (`lib/core/fill_pin_suggestion_parser.dart`)
///    returns a [FillPinSuggestion] with at least:
///    - [FillPinSuggestion.game] — `String?` display name (`Warzone`)
///    - [FillPinSuggestion.n] — `int?` current / starting party count
///    - [FillPinSuggestion.max] — `int?` party cap
///    - [FillPinSuggestion.shouldPropose] — `bool`
///    and a [FillPinSuggestion.chipLabel] of `Start {Game} {n}/{max}`
///    when a game is known (`Start Warzone 1/4`), or `Start {n}/{max}`
///    when the trigger is a bare ratio (`Start 1/4`).
///
/// 2. [partySizeMaxFor] + [kPartySizeMaxByGame]
///    (`lib/core/party_size_map.dart`) — curated max map. Warzone
///    default is **4**. [partySizeMaxFor] accepts `overrides:` so a
///    caller can replace a curated max without editing the map.
///    Matching is case-insensitive.
///
/// Trigger rules (under-trigger bias — prefer miss over false chip):
/// - Propose when trimmed text **is** a bare `n/max` (`1/4`).
/// - Propose when text has an explicit curated game token + `?`
///   (`warzone?`).
/// - Propose when text has an explicit curated game token + `n/max`
///   (`warzone 1/4`).
/// - Do **not** propose a ratio buried in narrative without a game
///   token or trailing `?` (`we went 2/4 last night`).
///
/// Bare `n/max` fills `n`/`max` from the ratio; `game` stays null.
/// `warzone?` fills `game=Warzone`, `n=1` (starter), `max` from the
/// party-size map (4 unless overridden). Explicit `n/max` in text
/// wins over the map for `n` and `max`.
///
/// Loop lease (≤3 under `lib/core/*` only — Tester does not edit):
/// 1. `lib/core/fill_pin_suggestion_parser.dart`
/// 2. `lib/core/party_size_map.dart`
///
/// Out of scope: chat_screen / chat_input_bar / chat_info_screen,
/// Tonight-tab, AASA, hosting, Agora, markdown, pubspec bump.
void main() {
  group('FillPinSuggestion output shape', () {
    test('exposes game, n, max, shouldPropose (and chipLabel)', () {
      final suggestion = parseFillPinSuggestion('warzone 1/4');

      expect(suggestion.game, isA<String?>());
      expect(suggestion.n, isA<int?>());
      expect(suggestion.max, isA<int?>());
      expect(suggestion.shouldPropose, isA<bool>());
      expect(suggestion.chipLabel, isA<String>());
    });
  });

  group('propose: bare 1/4, warzone?, warzone 1/4', () {
    test('bare 1/4 proposes Start 1/4 (n/max from ratio, no game token)', () {
      final suggestion = parseFillPinSuggestion('1/4');

      expect(suggestion.shouldPropose, isTrue);
      expect(suggestion.n, 1);
      expect(suggestion.max, 4);
      expect(suggestion.game, isNull);
      expect(suggestion.chipLabel, 'Start 1/4');
    });

    test('trimmed bare 1/4 still proposes', () {
      final suggestion = parseFillPinSuggestion('  1/4  ');

      expect(suggestion.shouldPropose, isTrue);
      expect(suggestion.n, 1);
      expect(suggestion.max, 4);
      expect(suggestion.game, isNull);
    });

    test('warzone? proposes Start Warzone 1/4 (n=1 starter, max from map)',
        () {
      final suggestion = parseFillPinSuggestion('warzone?');

      expect(suggestion.shouldPropose, isTrue);
      expect(suggestion.game, 'Warzone');
      expect(suggestion.n, 1);
      expect(suggestion.max, 4);
      expect(suggestion.chipLabel, 'Start Warzone 1/4');
    });

    test('Warzone? canonicalizes game and still proposes', () {
      final suggestion = parseFillPinSuggestion('Warzone?');

      expect(suggestion.shouldPropose, isTrue);
      expect(suggestion.game, 'Warzone');
      expect(suggestion.n, 1);
      expect(suggestion.max, 4);
    });

    test('warzone 1/4 proposes Start Warzone 1/4', () {
      final suggestion = parseFillPinSuggestion('warzone 1/4');

      expect(suggestion.shouldPropose, isTrue);
      expect(suggestion.game, 'Warzone');
      expect(suggestion.n, 1);
      expect(suggestion.max, 4);
      expect(suggestion.chipLabel, 'Start Warzone 1/4');
    });

    test('explicit n/max in text wins over the party-size map', () {
      final suggestion = parseFillPinSuggestion(
        'warzone 1/3',
        partySizeOverrides: const {'Warzone': 4},
      );

      expect(suggestion.shouldPropose, isTrue);
      expect(suggestion.game, 'Warzone');
      expect(suggestion.n, 1);
      expect(suggestion.max, 3);
      expect(suggestion.chipLabel, 'Start Warzone 1/3');
    });
  });

  group('under-trigger: narrative ratio without game or ?', () {
    test('we went 2/4 last night does not propose', () {
      final suggestion = parseFillPinSuggestion('we went 2/4 last night');

      expect(
        suggestion.shouldPropose,
        isFalse,
        reason: 'Narrative n/max without a game token or trailing ? '
            'must not chip. Cheap rule: require an explicit curated '
            'game token and/or a trailing ?, or a bare n/max text.',
      );
    });
  });

  group('party size map: Warzone default 4 + override hook', () {
    test('curated map default for Warzone is 4', () {
      expect(kPartySizeMaxByGame['Warzone'], 4);
      expect(partySizeMaxFor('Warzone'), 4);
      expect(partySizeMaxFor('warzone'), 4);
      expect(partySizeMaxFor('WARZONE'), 4);
    });

    test('overrides replace the curated max (contract hook)', () {
      expect(partySizeMaxFor('Warzone', overrides: const {'Warzone': 6}), 6);
      expect(partySizeMaxFor('warzone', overrides: const {'Warzone': 3}), 3);
    });

    test('parser reads override max for warzone? (no explicit n/max)', () {
      final suggestion = parseFillPinSuggestion(
        'warzone?',
        partySizeOverrides: const {'Warzone': 6},
      );

      expect(suggestion.shouldPropose, isTrue);
      expect(suggestion.game, 'Warzone');
      expect(suggestion.n, 1);
      expect(suggestion.max, 6);
      expect(suggestion.chipLabel, 'Start Warzone 1/6');
    });
  });
}
