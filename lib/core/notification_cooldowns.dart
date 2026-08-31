/// Per-key notification cooldown. Values are **expiry** instants
/// (`now + duration`), not "last sent" timestamps.
class NotificationCooldownStore {
  NotificationCooldownStore({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, DateTime> _expiryByKey = {};

  void setExpiry(String key, Duration duration) {
    _expiryByKey[key] = _clock().add(duration);
  }

  bool isActive(String key) {
    final expiry = _expiryByKey[key];
    if (expiry == null) return false;
    return _clock().isBefore(expiry);
  }

  Map<String, String> toIsoMap() =>
      _expiryByKey.map((key, value) => MapEntry(key, value.toIso8601String()));

  void loadIsoMap(Map<String, String> isoByKey) {
    _expiryByKey
      ..clear()
      ..addEntries(
        isoByKey.entries.map(
          (e) => MapEntry(e.key, DateTime.parse(e.value)),
        ),
      );
  }
}
