import 'dart:async';

import 'package:flutter/foundation.dart';

/// How long an "I'm on now" ping keeps the On badge.
const kAvailabilityOnDuration = Duration(minutes: 30);

/// In-memory "I'm on now" window from availability pings.
///
/// Sender marks on the live [AvailabilityPing.send] path. Recipients mark
/// from an incoming `availability_ping` payload ([observeAvailabilityPingPayload]).
/// Not a second notification presenter. Not a calendar.
class AvailabilityOnStore extends ChangeNotifier {
  AvailabilityOnStore({
    DateTime Function()? clock,
    this.duration = kAvailabilityOnDuration,
  }) : _clock = clock ?? DateTime.now;

  /// Widget tests leave a pending [Timer] if this is true. Production keeps
  /// it on so On badges drop when the window ends without a navigation.
  static bool scheduleExpirySweeps = true;

  final DateTime Function() _clock;
  final Duration duration;
  final Map<String, DateTime> _expiryByUid = {};
  Timer? _expiryTimer;

  void markOn(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return;
    _expiryByUid[uid] = _clock().add(duration);
    _scheduleExpirySweep();
    notifyListeners();
  }

  /// Read-only. Does not prune or notify — call [sweepExpired] to drop stale On.
  bool isOn(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return false;
    final expiry = _expiryByUid[uid];
    if (expiry == null) return false;
    return _clock().isBefore(expiry);
  }

  /// Drop expired On windows and notify so glance badges do not stay stale.
  /// Returns how many uids were removed.
  int sweepExpired() {
    final now = _clock();
    final stale = <String>[];
    _expiryByUid.forEach((uid, expiry) {
      if (!now.isBefore(expiry)) stale.add(uid);
    });
    if (stale.isEmpty) {
      _scheduleExpirySweep();
      return 0;
    }
    for (final uid in stale) {
      _expiryByUid.remove(uid);
    }
    _scheduleExpirySweep();
    notifyListeners();
    return stale.length;
  }

  /// Incoming FCM / local payload. Only `type=availability_ping`.
  void observePayload(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) return;
    final type = payload['type']?.toString().trim();
    if (type != 'availability_ping') return;
    final uid = _uidFromPayload(payload);
    if (uid == null) return;
    markOn(uid);
  }

  void clear() {
    _cancelExpiryTimer();
    if (_expiryByUid.isEmpty) return;
    _expiryByUid.clear();
    notifyListeners();
  }

  void cancelExpiryTimer() => _cancelExpiryTimer();

  void _cancelExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  void _scheduleExpirySweep() {
    _cancelExpiryTimer();
    if (!scheduleExpirySweeps) return;
    DateTime? soonest;
    final now = _clock();
    _expiryByUid.forEach((_, expiry) {
      if (!now.isBefore(expiry)) return;
      if (soonest == null || expiry.isBefore(soonest!)) soonest = expiry;
    });
    final next = soonest;
    if (next == null) return;
    var wait = next.difference(now);
    if (wait.isNegative) wait = Duration.zero;
    _expiryTimer = Timer(wait, () {
      sweepExpired();
    });
  }
}

String? _uidFromPayload(Map<String, dynamic> payload) {
  for (final key in ['from_uid', 'user_id', 'userId', 'uid']) {
    final text = payload[key]?.toString().trim();
    if (text != null && text.isNotEmpty && text != 'null') return text;
  }
  return null;
}

/// Shared store used by the I-am-on send path and incoming ping observe.
AvailabilityOnStore availabilityOnStore = AvailabilityOnStore();

void resetAvailabilityOnStore() {
  availabilityOnStore.cancelExpiryTimer();
  availabilityOnStore = AvailabilityOnStore();
}

/// Recipients (and any local display of the ping) mark the sender On.
void observeAvailabilityPingPayload(Map<String, dynamic>? payload) {
  availabilityOnStore.observePayload(payload);
}
