/// PIN WAVE P3B — Fill PIN visibility is group | public (XOR, never both).
///
/// Pure-Dart pin-scoped switch. Default is group. Clear / end drops that
/// pin's entry so resolve falls back to group. No chat UI, no Tonight,
/// no notify send path.
enum FillPinVisibility {
  group,
  public,
}

final Map<String, FillPinVisibility> _byPinId = {};

void resetFillPinVisibilityStore() {
  _byPinId.clear();
}

String? _pinKey(String pinId) {
  final trimmed = pinId.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Flip this pin to [visibility]. Group and public are XOR — one value.
void setFillPinVisibility(String pinId, FillPinVisibility visibility) {
  final key = _pinKey(pinId);
  if (key == null) return;
  _byPinId[key] = visibility;
}

/// Visibility for [pinId] only. Unset / unknown pins are group, not public.
FillPinVisibility resolveFillPinVisibility(String pinId) {
  final key = _pinKey(pinId);
  if (key == null) return FillPinVisibility.group;
  return _byPinId[key] ?? FillPinVisibility.group;
}

/// Ending / clearing the pin drops its visibility entry. Other pins stay.
void clearFillPinVisibilityOnEnd(String pinId) {
  final key = _pinKey(pinId);
  if (key == null) return;
  _byPinId.remove(key);
}
