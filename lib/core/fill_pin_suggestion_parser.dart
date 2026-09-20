import 'party_size_map.dart';

/// Pure-Dart Fill PIN suggestion. Chip UI is a later slice.
class FillPinSuggestion {
  const FillPinSuggestion({
    required this.game,
    required this.n,
    required this.max,
    required this.shouldPropose,
    required this.chipLabel,
  });

  /// Canonical display name (`Warzone`) when a curated token is present.
  final String? game;

  /// Current / starting party count.
  final int? n;

  /// Party cap.
  final int? max;

  /// Whether friends should see a Start chip.
  final bool shouldPropose;

  /// `Start {Game} {n}/{max}` when [game] is set, else `Start {n}/{max}`.
  final String chipLabel;
}

final _bareRatio = RegExp(r'^(\d+)/(\d+)$');
final _anyRatio = RegExp(r'(\d+)/(\d+)');

/// Parse chat text into a Fill PIN suggestion.
///
/// Under-trigger: propose only a bare `n/max`, a curated game + `?`,
/// or a curated game + `n/max`. Narrative ratios do not chip.
FillPinSuggestion parseFillPinSuggestion(
  String text, {
  Map<String, int>? partySizeOverrides,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const FillPinSuggestion(
      game: null,
      n: null,
      max: null,
      shouldPropose: false,
      chipLabel: '',
    );
  }

  final bare = _bareRatio.firstMatch(trimmed);
  if (bare != null) {
    final n = int.parse(bare.group(1)!);
    final max = int.parse(bare.group(2)!);
    return FillPinSuggestion(
      game: null,
      n: n,
      max: max,
      shouldPropose: true,
      chipLabel: 'Start $n/$max',
    );
  }

  final game = _curatedGameIn(trimmed);
  if (game == null) {
    return const FillPinSuggestion(
      game: null,
      n: null,
      max: null,
      shouldPropose: false,
      chipLabel: '',
    );
  }

  final ratio = _anyRatio.firstMatch(trimmed);
  if (ratio != null) {
    final n = int.parse(ratio.group(1)!);
    final max = int.parse(ratio.group(2)!);
    return FillPinSuggestion(
      game: game,
      n: n,
      max: max,
      shouldPropose: true,
      chipLabel: 'Start $game $n/$max',
    );
  }

  if (trimmed.endsWith('?')) {
    const n = 1;
    final max = partySizeMaxFor(game, overrides: partySizeOverrides);
    if (max == null) {
      return FillPinSuggestion(
        game: game,
        n: n,
        max: null,
        shouldPropose: false,
        chipLabel: '',
      );
    }
    return FillPinSuggestion(
      game: game,
      n: n,
      max: max,
      shouldPropose: true,
      chipLabel: 'Start $game $n/$max',
    );
  }

  return const FillPinSuggestion(
    game: null,
    n: null,
    max: null,
    shouldPropose: false,
    chipLabel: '',
  );
}

String? _curatedGameIn(String text) {
  final lower = text.toLowerCase();
  for (final key in kPartySizeMaxByGame.keys) {
    final token = key.toLowerCase();
    final pattern = RegExp('\\b${RegExp.escape(token)}\\b');
    if (pattern.hasMatch(lower)) return key;
  }
  return null;
}
