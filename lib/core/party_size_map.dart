/// Curated party-size maxima keyed by canonical game display name.
///
/// Matching in [partySizeMaxFor] is case-insensitive. [overrides] replace
/// a curated max without editing this map.
const Map<String, int> kPartySizeMaxByGame = <String, int>{
  'Warzone': 4,
};

/// Returns the party cap for [game], or `null` when the name is unknown.
///
/// [overrides] win over [kPartySizeMaxByGame]. Both maps match
/// case-insensitively so `warzone` + `{'Warzone': 6}` resolves to 6.
int? partySizeMaxFor(String game, {Map<String, int>? overrides}) {
  final trimmed = game.trim();
  if (trimmed.isEmpty) return null;
  if (overrides != null) {
    final overridden = _lookupIgnoreCase(overrides, trimmed);
    if (overridden != null) return overridden;
  }
  return _lookupIgnoreCase(kPartySizeMaxByGame, trimmed);
}

int? _lookupIgnoreCase(Map<String, int> map, String game) {
  final needle = game.toLowerCase();
  for (final entry in map.entries) {
    if (entry.key.toLowerCase() == needle) return entry.value;
  }
  return null;
}
