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
    final wrapped = clampMinutes(minutes);
    final hour = wrapped ~/ 60;
    final minute = wrapped % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Minutes from midnight in `0..1439`. Negative and overflow wrap the day.
  static int clampMinutes(int minutes) =>
      ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);

  /// Start inclusive, end exclusive. Overnight windows (start > end) wrap
  /// midnight. Equal start/end is not a window.
  ///
  /// Toggle off while the window is active immediately resumes — [enabled]
  /// false never suppresses, even at 23:00 in an overnight window.
  static bool isInQuietHours({
    required bool enabled,
    required int startMinutes,
    required int endMinutes,
    DateTime? now,
  }) {
    if (!enabled) return false;
    if (!hasQuietWindow(startMinutes, endMinutes)) return false;
    final start = clampMinutes(startMinutes);
    final end = clampMinutes(endMinutes);
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
  Object? lastError;
  bool _lastPersistWasSave = false;

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

  Future<HygienePersistResult> setSquadMuted(
    String squadId,
    bool muted, {
    Iterable<String> aliases = const [],
  }) async {
    final ids = <String>{
      if (NotificationHygiene._nonEmpty(squadId) != null) squadId.trim(),
      for (final alias in aliases)
        if (NotificationHygiene._nonEmpty(alias) != null) alias.trim(),
    };
    if (ids.isEmpty) return const HygienePersistResult.ok();
    if (muted) {
      mutedSquadIds.addAll(ids);
    } else {
      mutedSquadIds.removeAll(ids);
    }
    return save();
  }

  Future<HygienePersistResult> setQuietHours({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
  }) async {
    if (enabled != null) quietHoursEnabled = enabled;
    if (startMinutes != null) {
      this.startMinutes = NotificationHygiene.clampMinutes(startMinutes);
    }
    if (endMinutes != null) {
      this.endMinutes = NotificationHygiene.clampMinutes(endMinutes);
    }
    return save();
  }

  Future<HygienePersistResult> load() async {
    _lastPersistWasSave = false;
    final result = await runHygienePersist(() async {
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
    });
    lastError = result.error;
    if (!result.isOk) {
      debugPrint('NotificationHygieneStore.load failed: ${result.error}');
    }
    return result;
  }

  Future<HygienePersistResult> save() async {
    _lastPersistWasSave = true;
    final result = await runHygienePersist(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(mutedPrefsKey, mutedSquadIds.toList());
      await prefs.setBool(quietEnabledPrefsKey, quietHoursEnabled);
      await prefs.setInt(quietStartPrefsKey, startMinutes);
      await prefs.setInt(quietEndPrefsKey, endMinutes);
      for (final id in mutedSquadIds) {
        await prefs.setBool('chat_muted_$id', true);
      }
    });
    lastError = result.error;
    if (!result.isOk) {
      debugPrint('NotificationHygieneStore.save failed: ${result.error}');
    }
    return result;
  }

  /// Re-run the last persist. Failed writes save current memory; otherwise
  /// reload from disk.
  Future<HygienePersistResult> retry() => _lastPersistWasSave ? save() : load();

  @visibleForTesting
  void reset() {
    mutedSquadIds.clear();
    quietHoursEnabled = false;
    startMinutes = NotificationHygiene.defaultStartMinutes;
    endMinutes = NotificationHygiene.defaultEndMinutes;
    clock = DateTime.now;
    lastError = null;
    _lastPersistWasSave = false;
  }
}

/// Settings copy + persist mapper. Same [NotificationHygiene] gate — no
/// second presenter.
enum QuietHoursPhase { off, emptySchedule, on, error }

enum MuteThisSquadPhase { off, on, error }

const kQuietHoursRetryLabel = 'Retry';
const kMuteThisSquadRetryLabel = 'Retry';

const kQuietHoursErrorCopy = "Couldn't update quiet hours";
const kQuietHoursErrorHint = 'Check your connection and try again.';
const kQuietHoursEmptyScheduleCopy =
    'No quiet window — start and end are the same.';
const kQuietHoursEmptyScheduleHint =
    'Notifications stay on until you pick different times.';
const kQuietHoursActiveNowHint = 'Turn off to resume pings.';
const kQuietHoursOffEmptyWindowCopy =
    'Off — pick a start and end to pause notification sends.';

const kMuteThisSquadTitle = 'Mute this squad';
const kMuteThisSquadEmptyCopy = 'Notifications from this squad stay on';
const kMuteThisSquadOnCopy = 'No pings from this squad until you unmute';
const kMuteThisSquadErrorCopy = "Couldn't update mute";
const kMuteThisSquadErrorHint = 'Check your connection and try again.';

class HygienePersistResult {
  const HygienePersistResult.ok() : error = null;
  const HygienePersistResult.error(this.error);

  final Object? error;

  bool get isOk => error == null;
}

/// Equal start/end (after wrap) is not a window — empty schedule.
bool hasQuietWindow(int startMinutes, int endMinutes) {
  return NotificationHygiene.clampMinutes(startMinutes) !=
      NotificationHygiene.clampMinutes(endMinutes);
}

/// Start after end in the same calendar day — wraps past midnight.
bool isOvernightQuietWindow(int startMinutes, int endMinutes) {
  if (!hasQuietWindow(startMinutes, endMinutes)) return false;
  return NotificationHygiene.clampMinutes(startMinutes) >
      NotificationHygiene.clampMinutes(endMinutes);
}

String quietHoursWindowLabel(int startMinutes, int endMinutes) {
  final start = NotificationHygiene.formatMinutes(startMinutes);
  final end = NotificationHygiene.formatMinutes(endMinutes);
  if (isOvernightQuietWindow(startMinutes, endMinutes)) {
    return '$start – $end overnight';
  }
  return '$start – $end';
}

QuietHoursPhase resolveQuietHoursPhase({
  required bool enabled,
  required int startMinutes,
  required int endMinutes,
  Object? error,
}) {
  if (error != null) return QuietHoursPhase.error;
  if (!enabled) return QuietHoursPhase.off;
  if (!hasQuietWindow(startMinutes, endMinutes)) {
    return QuietHoursPhase.emptySchedule;
  }
  return QuietHoursPhase.on;
}

Key quietHoursPhaseKey(QuietHoursPhase phase, {bool activeNow = false}) {
  switch (phase) {
    case QuietHoursPhase.off:
      return const Key('quiet-hours-empty');
    case QuietHoursPhase.emptySchedule:
      return const Key('quiet-hours-empty-schedule');
    case QuietHoursPhase.error:
      return const Key('quiet-hours-error');
    case QuietHoursPhase.on:
      return activeNow
          ? const Key('quiet-hours-active-now')
          : const Key('quiet-hours-on');
  }
}

Key quietHoursHintKey(QuietHoursPhase phase) {
  return phase == QuietHoursPhase.error
      ? const Key('quiet-hours-error-hint')
      : const Key('quiet-hours-empty-schedule-hint');
}

String quietHoursMessage({
  required QuietHoursPhase phase,
  required int startMinutes,
  required int endMinutes,
  bool activeNow = false,
}) {
  switch (phase) {
    case QuietHoursPhase.error:
      return kQuietHoursErrorCopy;
    case QuietHoursPhase.emptySchedule:
      return kQuietHoursEmptyScheduleCopy;
    case QuietHoursPhase.off:
      if (!hasQuietWindow(startMinutes, endMinutes)) {
        return kQuietHoursOffEmptyWindowCopy;
      }
      return 'Off — pause all notification sends ${quietHoursWindowLabel(startMinutes, endMinutes)}';
    case QuietHoursPhase.on:
      if (activeNow) {
        return 'Pausing now through ${NotificationHygiene.formatMinutes(endMinutes)}. $kQuietHoursActiveNowHint';
      }
      return 'Pausing all notification sends ${quietHoursWindowLabel(startMinutes, endMinutes)}';
  }
}

String? quietHoursHint(QuietHoursPhase phase) {
  switch (phase) {
    case QuietHoursPhase.error:
      return kQuietHoursErrorHint;
    case QuietHoursPhase.emptySchedule:
      return kQuietHoursEmptyScheduleHint;
    case QuietHoursPhase.off:
    case QuietHoursPhase.on:
      return null;
  }
}

MuteThisSquadPhase resolveMuteThisSquadPhase({
  required bool muted,
  Object? error,
}) {
  if (error != null) return MuteThisSquadPhase.error;
  return muted ? MuteThisSquadPhase.on : MuteThisSquadPhase.off;
}

Key muteThisSquadPhaseKey(MuteThisSquadPhase phase) {
  switch (phase) {
    case MuteThisSquadPhase.off:
      return const Key('mute-this-squad-empty');
    case MuteThisSquadPhase.on:
      return const Key('mute-this-squad-on');
    case MuteThisSquadPhase.error:
      return const Key('mute-this-squad-error');
  }
}

String muteThisSquadMessage(MuteThisSquadPhase phase) {
  switch (phase) {
    case MuteThisSquadPhase.error:
      return kMuteThisSquadErrorCopy;
    case MuteThisSquadPhase.on:
      return kMuteThisSquadOnCopy;
    case MuteThisSquadPhase.off:
      return kMuteThisSquadEmptyCopy;
  }
}

String? muteThisSquadHint(MuteThisSquadPhase phase) {
  return phase == MuteThisSquadPhase.error ? kMuteThisSquadErrorHint : null;
}

String? hygieneErrorDetail(Object? error) {
  if (error == null) return null;
  final text = error.toString().trim();
  if (text.isEmpty) return null;
  const prefix = 'Exception: ';
  if (text.startsWith(prefix) && text.length > prefix.length) {
    return text.substring(prefix.length);
  }
  return text;
}

/// Map a persist attempt. Thrown write is error. Retry is calling this again.
Future<HygienePersistResult> runHygienePersist(
  Future<void> Function() persist,
) async {
  try {
    await persist();
    return const HygienePersistResult.ok();
  } catch (e) {
    return HygienePersistResult.error(e);
  }
}

Future<HygienePersistResult> retryHygienePersist(
  Future<void> Function() persist,
) =>
    runHygienePersist(persist);
