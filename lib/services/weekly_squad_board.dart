import 'dart:convert';

import 'package:squad_sync/services/session_rating_machine.dart';

/// Rolling window for the weekly squad board. UTC, inclusive of [now].
const kWeeklySquadBoardWindow = Duration(days: 7);

const kWeeklySquadBoardEmptyCopy = 'No nights recorded this week';

/// One squad member's weekly line on the board.
class WeeklySquadBoardRow {
  const WeeklySquadBoardRow({
    required this.uid,
    required this.label,
    this.nightsPlayed = 0,
    this.lockInRate,
    this.commsAverage,
    this.vibesAverage,
  });

  final String uid;
  final String label;
  final int nightsPlayed;
  final double? lockInRate;
  final double? commsAverage;
  final double? vibesAverage;
}

/// Squad-scoped weekly aggregates from `match_history` + existing ratings.
///
/// Nights = unique UTC dates with a recorded session. Lock-in = share of
/// those nights that have a session rating (or a `locked` notes flag).
/// Comms / vibes come from session-rating notes, then player category maps
/// (RatingsDialog `Comms` / `Vibes`), then session stars as vibes fallback.
class WeeklySquadBoard {
  const WeeklySquadBoard({
    this.nightsPlayed = 0,
    this.lockInRate,
    this.commsAverage,
    this.vibesAverage,
    this.commsSampleSize = 0,
    this.vibesSampleSize = 0,
    this.rows = const [],
  });

  const WeeklySquadBoard.empty() : this();

  final int nightsPlayed;
  final double? lockInRate;
  final double? commsAverage;
  final double? vibesAverage;
  final int commsSampleSize;
  final int vibesSampleSize;
  final List<WeeklySquadBoardRow> rows;

  bool get isEmpty => nightsPlayed == 0 && rows.isEmpty;
}

DateTime weeklySquadBoardCutoff(DateTime now) =>
    now.toUtc().subtract(kWeeklySquadBoardWindow);

String weeklySquadBoardLockInLabel(double? rate) {
  if (rate == null) return '—';
  return '${(rate * 100).round()}%';
}

String weeklySquadBoardScoreLabel(double? value) {
  if (value == null) return '—';
  return value.toStringAsFixed(1);
}

/// Compact member line: `Sam · 4n · 75% · C4.5 · V4.0`.
String weeklySquadBoardRowLabel(WeeklySquadBoardRow row) {
  final parts = <String>[row.label, '${row.nightsPlayed}n'];
  if (row.lockInRate != null) {
    parts.add(weeklySquadBoardLockInLabel(row.lockInRate));
  }
  if (row.commsAverage != null) {
    parts.add('C${weeklySquadBoardScoreLabel(row.commsAverage)}');
  }
  if (row.vibesAverage != null) {
    parts.add('V${weeklySquadBoardScoreLabel(row.vibesAverage)}');
  }
  return parts.join(' · ');
}

/// Weekly board from `match_history` rows. Pure; no I/O.
WeeklySquadBoard weeklySquadBoardFromHistory(
  List<Map<String, dynamic>> rows, {
  DateTime? now,
  List<String> memberUids = const [],
  Map<String, String> displayNames = const {},
  Map<String, Map<String, int>> categoryRatings = const {},
}) {
  final clock = (now ?? DateTime.now()).toUtc();
  final cutoff = weeklySquadBoardCutoff(clock);
  final weekly = <_WeeklySession>[];
  for (final row in rows) {
    final session = _sessionFromRow(row);
    if (session == null) continue;
    if (session.when.isBefore(cutoff)) continue;
    weekly.add(session);
  }

  if (weekly.isEmpty) {
    return const WeeklySquadBoard.empty();
  }

  final nights = <String>{};
  final lockedNights = <String>{};
  var commsTotal = 0;
  var commsCount = 0;
  var vibesTotal = 0;
  var vibesCount = 0;

  for (final session in weekly) {
    nights.add(session.nightKey);
    if (session.lockedIn) lockedNights.add(session.nightKey);
    if (session.comms != null) {
      commsTotal += session.comms!;
      commsCount++;
    }
    if (session.vibes != null) {
      vibesTotal += session.vibes!;
      vibesCount++;
    }
  }

  if (commsCount == 0) {
    final fromMaps = _categoryAverage(categoryRatings, _isCommsKey);
    if (fromMaps != null) {
      commsTotal = fromMaps.$1;
      commsCount = fromMaps.$2;
    }
  }
  if (vibesCount == 0) {
    final fromMaps = _categoryAverage(categoryRatings, _isVibesKey);
    if (fromMaps != null) {
      vibesTotal = fromMaps.$1;
      vibesCount = fromMaps.$2;
    }
  }
  if (vibesCount == 0) {
    for (final session in weekly) {
      if (session.stars == null) continue;
      vibesTotal += session.stars!;
      vibesCount++;
    }
  }

  final nightsPlayed = nights.length;
  final lockInRate =
      nightsPlayed == 0 ? null : lockedNights.length / nightsPlayed;

  final roster = <String>{
    ...memberUids.where((id) => id.isNotEmpty),
  };
  for (final session in weekly) {
    roster.addAll(session.playerUids);
  }

  final memberRows = <WeeklySquadBoardRow>[];
  for (final uid in roster) {
    final memberNights = <String>{};
    final memberLocked = <String>{};
    var memberCommsTotal = 0;
    var memberCommsCount = 0;
    var memberVibesTotal = 0;
    var memberVibesCount = 0;
    var memberStarsTotal = 0;
    var memberStarsCount = 0;

    for (final session in weekly) {
      // Missing player_uids must not credit every squad member.
      if (session.playerUids.isEmpty) continue;
      if (!session.playerUids.contains(uid)) continue;
      memberNights.add(session.nightKey);
      if (session.lockedIn) memberLocked.add(session.nightKey);
      if (session.comms != null) {
        memberCommsTotal += session.comms!;
        memberCommsCount++;
      }
      if (session.vibes != null) {
        memberVibesTotal += session.vibes!;
        memberVibesCount++;
      }
      if (session.stars != null) {
        memberStarsTotal += session.stars!;
        memberStarsCount++;
      }
    }
    if (memberNights.isEmpty) continue;

    final fromComms = _playerCategory(categoryRatings, uid, _isCommsKey);
    final fromVibes = _playerCategory(categoryRatings, uid, _isVibesKey);
    final commsAvg = fromComms ??
        (memberCommsCount == 0 ? null : memberCommsTotal / memberCommsCount);
    var vibesAvg = fromVibes ??
        (memberVibesCount == 0 ? null : memberVibesTotal / memberVibesCount);
    if (vibesAvg == null && memberStarsCount > 0) {
      vibesAvg = memberStarsTotal / memberStarsCount;
    }

    final name = displayNames[uid];
    memberRows.add(
      WeeklySquadBoardRow(
        uid: uid,
        label: (name != null && name.isNotEmpty) ? name : uid,
        nightsPlayed: memberNights.length,
        lockInRate: memberLocked.length / memberNights.length,
        commsAverage: commsAvg,
        vibesAverage: vibesAvg,
      ),
    );
  }

  memberRows.sort(_compareRows);

  return WeeklySquadBoard(
    nightsPlayed: nightsPlayed,
    lockInRate: lockInRate,
    commsAverage: commsCount == 0 ? null : commsTotal / commsCount,
    vibesAverage: vibesCount == 0 ? null : vibesTotal / vibesCount,
    commsSampleSize: commsCount,
    vibesSampleSize: vibesCount,
    rows: memberRows,
  );
}

int _compareRows(WeeklySquadBoardRow a, WeeklySquadBoardRow b) {
  final byNights = b.nightsPlayed.compareTo(a.nightsPlayed);
  if (byNights != 0) return byNights;
  final byLock = (b.lockInRate ?? -1).compareTo(a.lockInRate ?? -1);
  if (byLock != 0) return byLock;
  final byVibes = (b.vibesAverage ?? -1).compareTo(a.vibesAverage ?? -1);
  if (byVibes != 0) return byVibes;
  return a.label.toLowerCase().compareTo(b.label.toLowerCase());
}

class _WeeklySession {
  const _WeeklySession({
    required this.when,
    required this.nightKey,
    required this.lockedIn,
    required this.playerUids,
    this.stars,
    this.comms,
    this.vibes,
  });

  final DateTime when;
  final String nightKey;
  final bool lockedIn;
  final List<String> playerUids;
  final int? stars;
  final int? comms;
  final int? vibes;
}

_WeeklySession? _sessionFromRow(Map<String, dynamic> row) {
  final rating = sessionRatingFromMatchRow(row);
  final notes = _notesObject(row['notes']);
  final nested = _sessionRatingPayload(notes);
  final when = rating?.ratedAt?.toUtc() ??
      _asDateTime(row['created_at'] ?? row['createdAt'] ?? row['timestamp'])
          ?.toUtc();
  if (when == null) return null;

  final comms = _asInt(nested['comms'] ?? nested['Comms']);
  final vibes = _asInt(nested['vibes'] ?? nested['Vibes']);
  final lockedFlag = _asBool(
    nested['locked'] ??
        nested['lock_in'] ??
        notes['locked'] ??
        notes['lock_in'],
  );
  final lockedIn =
      (rating != null && rating.isRated) || lockedFlag == true;

  return _WeeklySession(
    when: when,
    nightKey: _nightKey(when),
    lockedIn: lockedIn,
    playerUids: _playersOf(row),
    stars: rating?.stars,
    comms: isValidSessionStars(comms) ? comms : null,
    vibes: isValidSessionStars(vibes) ? vibes : null,
  );
}

String _nightKey(DateTime when) {
  final utc = when.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}

Map<String, dynamic> _sessionRatingPayload(Map<String, dynamic> notes) {
  final raw = notes[kSessionRatingNotesKey] ?? notes['sessionRating'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return notes;
}

(int, int)? _categoryAverage(
  Map<String, Map<String, int>> ratings,
  bool Function(String key) match,
) {
  var total = 0;
  var count = 0;
  for (final entry in ratings.entries) {
    if (match(entry.key)) {
      for (final value in entry.value.values) {
        if (!isValidSessionStars(value)) continue;
        total += value;
        count++;
      }
      continue;
    }
    for (final inner in entry.value.entries) {
      if (!match(inner.key) || !isValidSessionStars(inner.value)) continue;
      total += inner.value;
      count++;
    }
  }
  if (count == 0) return null;
  return (total, count);
}

double? _playerCategory(
  Map<String, Map<String, int>> ratings,
  String uid,
  bool Function(String key) match,
) {
  final direct = ratings[uid];
  if (direct != null) {
    for (final entry in direct.entries) {
      if (match(entry.key) && isValidSessionStars(entry.value)) {
        return entry.value.toDouble();
      }
    }
  }
  for (final entry in ratings.entries) {
    if (!match(entry.key)) continue;
    final value = entry.value[uid];
    if (isValidSessionStars(value)) return value!.toDouble();
  }
  return null;
}

bool _isCommsKey(String key) {
  final k = key.toLowerCase().trim();
  return k == 'comms' || k == 'comm' || k == 'communication';
}

bool _isVibesKey(String key) {
  final k = key.toLowerCase().trim();
  return k == 'vibes' || k == 'vibe';
}

Map<String, dynamic> _notesObject(dynamic existing) {
  if (existing == null) return <String, dynamic>{};
  if (existing is Map) return Map<String, dynamic>.from(existing);
  if (existing is String) {
    final trimmed = existing.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return <String, dynamic>{'text': existing};
      }
    }
    return <String, dynamic>{'text': existing};
  }
  return <String, dynamic>{};
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return num.tryParse(value.trim())?.toInt();
  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.toLowerCase().trim()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
    }
  }
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) {
    if (value > 9999999999) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }
  return null;
}

List<String> _playersOf(Map<String, dynamic> entry) {
  for (final key in [
    'player_uids',
    'playerUids',
    'memberUids',
    'member_uids',
    'players',
    'members',
  ]) {
    final parsed = _parsePlayerList(entry[key]);
    if (parsed != null) return parsed;
  }
  return const [];
}

List<String>? _parsePlayerList(Object? value) {
  if (value == null) return null;
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final inner = trimmed.substring(1, trimmed.length - 1).trim();
      if (inner.isEmpty) return const [];
      return inner
          .split(',')
          .map((e) => e.trim().replaceAll('"', ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }
  return null;
}
