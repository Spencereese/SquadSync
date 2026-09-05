import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mute-this-squad + quiet hours. Live path: [NotificationService] /
/// [NotificationManager] consult this before local show or FCM send.
///
/// Not a second presenter — same pipeline, extra gate.
class NotificationHygieneSnapshot {
  const NotificationHygieneSnapshot({
    required this.mutedSquadIds,
    required this.quietHoursEnabled,
    required this.startMinutes,
    required this.endMinutes,
  });

  static const empty = NotificationHygieneSnapshot(
    mutedSquadIds: {},
    quietHoursEnabled: false,
    startMinutes: NotificationHygiene.defaultStartMinutes,
    endMinutes: NotificationHygiene.defaultEndMinutes,
  );

  final Set<String> mutedSquadIds;
  final bool quietHoursEnabled;
  final int startMinutes;
  final int endMinutes;
}

class NotificationHygiene {
  NotificationHygiene._();

  /// 22:00 local.
  static const defaultStartMinutes = 22 * 60;

  /// 08:00 local.
  static const defaultEndMinutes = 8 * 60;

  static const _idKeys = <String>[
    'lobby_id',
    'lobbyId',
    'lobby',
    'squad_id',
    'squadId',
    'chat_group_id',
    'chatGroupId',
    'group_id',
    'groupId',
  ];

  /// Minutes from midnight in [now]'s calendar (local or UTC as given).
  static int minutesOfDay(DateTime now) => now.hour * 60 + now.minute;

  static String formatMinutes(int minutes) {
    final wrapped = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    final hour = wrapped ~/ 60;
    final minute = wrapped % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Start inclusive, end exclusive. Overnight windows (start > end) wrap
  /// midnight. Equal start/end is not a window.
  static bool isInQuietHours({
    required bool enabled,
    required int startMinutes,
    required int endMinutes,
    DateTime? now,
  }) {
    if (!enabled) return false;
    final start = _clampMinutes(startMinutes);
    final end = _clampMinutes(endMinutes);
    if (start == end) return false;
    final minutes = minutesOfDay(now ?? DateTime.now());
    if (start < end) {
      return minutes >= start && minutes < end;
    }
    return minutes >= start || minutes < end;
  }

  static Set<String> idsInPayload(Map<String, dynamic> payload) {
    final ids = <String>{};
    for (final key in _idKeys) {
      final id = _nonEmpty(payload[key]);
      if (id != null) ids.add(id);
    }
    return ids;
  }

  static bool isSquadMuted(
    Map<String, dynamic> payload,
    Set<String> mutedSquadIds,
  ) {
    if (mutedSquadIds.isEmpty) return false;
    for (final id in idsInPayload(payload)) {
      if (mutedSquadIds.contains(id)) return true;
    }
    return false;
  }

  /// Local display: muted squad or quiet hours.
  static bool shouldSuppressShow({
    required Map<String, dynamic> payload,
    required NotificationHygieneSnapshot settings,
    DateTime? now,
  }) {
    if (isSquadMuted(payload, settings.mutedSquadIds)) return true;
    return isInQuietHours(
      enabled: settings.quietHoursEnabled,
      startMinutes: settings.startMinutes,
      endMinutes: settings.endMinutes,
      now: now,
    );
  }

  /// FCM send: quiet hours drop every recipient. Mute drops only [currentUid]
  /// so teammates still get the ping and this device is not FCM'd to self.
  static List<String> recipientsAfterHygiene({
    required List<String> recipientUids,
    required Map<String, dynamic> payload,
    required NotificationHygieneSnapshot settings,
    String? currentUid,
    DateTime? now,
  }) {
    if (isInQuietHours(
      enabled: settings.quietHoursEnabled,
      startMinutes: settings.startMinutes,
      endMinutes: settings.endMinutes,
      now: now,
    )) {
      return const [];
    }
    if (!isSquadMuted(payload, settings.mutedSquadIds)) {
      return recipientUids;
    }
    final self = currentUid?.trim();
    if (self == null || self.isEmpty) return recipientUids;
    return [
      for (final uid in recipientUids)
        if (uid != self) uid,
    ];
  }

  static int _clampMinutes(int minutes) =>
      ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}

/// In-memory + SharedPreferences. [NotificationService.initialize] loads it.
class NotificationHygieneStore {
  NotificationHygieneStore({DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  static const mutedPrefsKey = 'notification_hygiene_muted_squads';
  static const quietEnabledPrefsKey = 'notification_hygiene_quiet_enabled';
  static const quietStartPrefsKey = 'notification_hygiene_quiet_start';
  static const quietEndPrefsKey = 'notification_hygiene_quiet_end';

  static final NotificationHygieneStore instance = NotificationHygieneStore();

  DateTime Function() clock;
  final Set<String> mutedSquadIds = {};
  bool quietHoursEnabled = false;
  int startMinutes = NotificationHygiene.defaultStartMinutes;
  int endMinutes = NotificationHygiene.defaultEndMinutes;

  NotificationHygieneSnapshot get snapshot => NotificationHygieneSnapshot(
        mutedSquadIds: Set<String>.from(mutedSquadIds),
        quietHoursEnabled: quietHoursEnabled,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      );

  bool isSquadIdMuted(String squadId) {
    final id = squadId.trim();
    if (id.isEmpty) return false;
    return mutedSquadIds.contains(id);
  }

  bool shouldSuppressShow(Map<String, dynamic> payload, {DateTime? now}) {
    return NotificationHygiene.shouldSuppressShow(
      payload: payload,
      settings: snapshot,
      now: now ?? clock(),
    );
  }

  List<String> recipientsForSend({
    required List<String> recipientUids,
    Map<String, dynamic>? data,
    String? currentUid,
    DateTime? now,
  }) {
    return NotificationHygiene.recipientsAfterHygiene(
      recipientUids: recipientUids,
      payload: data ?? const {},
      settings: snapshot,
      currentUid: currentUid,
      now: now ?? clock(),
    );
  }

  Future<void> setSquadMuted(
    String squadId,
    bool muted, {
    Iterable<String> aliases = const [],
  }) async {
    final ids = <String>{
      if (NotificationHygiene._nonEmpty(squadId) != null) squadId.trim(),
      for (final alias in aliases)
        if (NotificationHygiene._nonEmpty(alias) != null) alias.trim(),
    };
    if (ids.isEmpty) return;
    if (muted) {
      mutedSquadIds.addAll(ids);
    } else {
      mutedSquadIds.removeAll(ids);
    }
    await save();
  }

  Future<void> setQuietHours({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
  }) async {
    if (enabled != null) quietHoursEnabled = enabled;
    if (startMinutes != null) {
      this.startMinutes = NotificationHygiene._clampMinutes(startMinutes);
    }
    if (endMinutes != null) {
      this.endMinutes = NotificationHygiene._clampMinutes(endMinutes);
    }
    await save();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(mutedPrefsKey);
      if (stored != null) {
        mutedSquadIds
          ..clear()
          ..addAll(stored.where((id) => id.trim().isNotEmpty));
      }
      for (final key in prefs.getKeys()) {
        if (key.startsWith('chat_muted_') && prefs.getBool(key) == true) {
          final id = key.substring('chat_muted_'.length).trim();
          if (id.isNotEmpty) mutedSquadIds.add(id);
        }
      }
      quietHoursEnabled = prefs.getBool(quietEnabledPrefsKey) ?? false;
      startMinutes = prefs.getInt(quietStartPrefsKey) ??
          NotificationHygiene.defaultStartMinutes;
      endMinutes = prefs.getInt(quietEndPrefsKey) ??
          NotificationHygiene.defaultEndMinutes;
    } catch (e) {
      debugPrint('NotificationHygieneStore.load failed: $e');
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(mutedPrefsKey, mutedSquadIds.toList());
      await prefs.setBool(quietEnabledPrefsKey, quietHoursEnabled);
      await prefs.setInt(quietStartPrefsKey, startMinutes);
      await prefs.setInt(quietEndPrefsKey, endMinutes);
      for (final id in mutedSquadIds) {
        await prefs.setBool('chat_muted_$id', true);
      }
    } catch (e) {
      debugPrint('NotificationHygieneStore.save failed: $e');
    }
  }

  @visibleForTesting
  void reset() {
    mutedSquadIds.clear();
    quietHoursEnabled = false;
    startMinutes = NotificationHygiene.defaultStartMinutes;
    endMinutes = NotificationHygiene.defaultEndMinutes;
    clock = DateTime.now;
  }
}
