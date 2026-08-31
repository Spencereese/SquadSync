/// Per-key notification cooldown. Values are **expiry** instants
/// (`now + duration`), not "last sent" timestamps.
///
/// Prefs v1 (`notification_cooldowns`) stored last-sent times. Loading those
/// as expiry made every old key immediately inactive. v2 stores
/// `{ "v": 2, "expiry": { key: iso } }`. [loadPersisted] migrates v1 by
/// adding [legacyDefaultDuration] to each last-sent stamp.
class NotificationCooldownStore {
  NotificationCooldownStore({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const prefsKeyV1 = 'notification_cooldowns';
  static const prefsKeyV2 = 'notification_cooldowns_v2';
  static const currentVersion = 2;
  static const defaultDuration = Duration(minutes: 45);
  static const momentumDuration = Duration(minutes: 30);

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

  /// JSON written to [prefsKeyV2].
  Map<String, dynamic> toPersistedJson() => {
        'v': currentVersion,
        'expiry': toIsoMap(),
      };

  /// Load v2 expiry map, or migrate v1 last-sent → expiry.
  /// Returns true if a v1 record was migrated (caller should persist v2).
  bool loadPersisted(
    dynamic decoded, {
    Duration legacyDefaultDuration = defaultDuration,
  }) {
    if (decoded is Map && decoded['v'] == currentVersion) {
      final expiry = decoded['expiry'];
      if (expiry is Map) {
        loadIsoMap({
          for (final e in expiry.entries)
            if (e.value is String) e.key.toString(): e.value as String,
        });
        return false;
      }
    }
    if (decoded is Map) {
      migrateLastSentToExpiry(decoded, legacyDefaultDuration);
      return true;
    }
    return false;
  }

  /// v1 values were last-sent timestamps. A later unversioned write stored
  /// expiry in the same key — if the stamp is still in the future, keep it.
  void migrateLastSentToExpiry(
    Map<dynamic, dynamic> lastSentByKey,
    Duration duration,
  ) {
    final now = _clock();
    _expiryByKey.clear();
    for (final e in lastSentByKey.entries) {
      if (e.value is! String) continue;
      try {
        final stamp = DateTime.parse(e.value as String);
        _expiryByKey[e.key.toString()] =
            stamp.isAfter(now) ? stamp : stamp.add(duration);
      } catch (_) {}
    }
  }
}
