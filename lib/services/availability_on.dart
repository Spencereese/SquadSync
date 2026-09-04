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

  final DateTime Function() _clock;
  final Duration duration;
  final Map<String, DateTime> _expiryByUid = {};

  void markOn(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return;
    _expiryByUid[uid] = _clock().add(duration);
    notifyListeners();
  }

  bool isOn(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return false;
    final expiry = _expiryByUid[uid];
    if (expiry == null) return false;
    if (!_clock().isBefore(expiry)) {
      _expiryByUid.remove(uid);
      return false;
    }
    return true;
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
    if (_expiryByUid.isEmpty) return;
    _expiryByUid.clear();
    notifyListeners();
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
  availabilityOnStore = AvailabilityOnStore();
}

/// Recipients (and any local display of the ping) mark the sender On.
void observeAvailabilityPingPayload(Map<String, dynamic>? payload) {
  availabilityOnStore.observePayload(payload);
}
