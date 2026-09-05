import 'dart:convert';

/// 1–5 star rating of a squad session after it ends.
///
/// Persistence is the existing `match_history.notes` TEXT column (JSON),
/// not a new table. The reducer is pure; I/O lives in [LobbyNotifier].
enum SessionRatingPhase {
  unrated,
  rated,
  skipped,
}

enum SessionRatingEvent {
  rate,
  skip,
  clear,
}

/// Clip metadata attached to a rated session (`match_history.notes`).
///
/// Sibling of [kSessionRatingNotesKey] — not a new table. Media pick uses
/// the existing gallery hook; this stores the metadata, not a clips product.
class SessionClip {
  const SessionClip({
    this.clipId,
    this.videoUrl,
    this.thumbUrl,
    this.durationMs,
    this.title,
    this.fileName,
    this.source,
    this.attachedAt,
  });

  static const empty = SessionClip();

  final String? clipId;
  final String? videoUrl;
  final String? thumbUrl;
  final int? durationMs;
  final String? title;
  final String? fileName;
  final String? source;
  final DateTime? attachedAt;

  bool get isAttached => _nonEmpty(clipId) != null;

  SessionClip copyWith({
    String? clipId,
    String? videoUrl,
    String? thumbUrl,
    int? durationMs,
    String? title,
    String? fileName,
    String? source,
    DateTime? attachedAt,
    bool clear = false,
  }) {
    return SessionClip(
      clipId: clear ? null : (clipId ?? this.clipId),
      videoUrl: clear ? null : (videoUrl ?? this.videoUrl),
      thumbUrl: clear ? null : (thumbUrl ?? this.thumbUrl),
      durationMs: clear ? null : (durationMs ?? this.durationMs),
      title: clear ? null : (title ?? this.title),
      fileName: clear ? null : (fileName ?? this.fileName),
      source: clear ? null : (source ?? this.source),
      attachedAt: clear ? null : (attachedAt ?? this.attachedAt),
    );
  }
}

enum SessionClipEvent {
  attach,
  skip,
  clear,
}

/// Snapshot of one user's rating of one ended squad session.
class SessionRatingState {
  const SessionRatingState({
    this.phase = SessionRatingPhase.unrated,
    this.stars,
    this.lobbyId,
    this.raterUid,
    this.matchId,
    this.gameName,
    this.result,
    this.comment,
    this.ratedAt,
    this.clip,
  });

  static const unrated = SessionRatingState();

  final SessionRatingPhase phase;
  final int? stars;
  final String? lobbyId;
  final String? raterUid;
  final String? matchId;
  final String? gameName;
  final String? result;
  final String? comment;
  final DateTime? ratedAt;
  final SessionClip? clip;

  bool get isRated =>
      phase == SessionRatingPhase.rated && isValidSessionStars(stars);

  bool get hasClip => clip != null && clip!.isAttached;

  SessionRatingState copyWith({
    SessionRatingPhase? phase,
    int? stars,
    String? lobbyId,
    String? raterUid,
    String? matchId,
    String? gameName,
    String? result,
    String? comment,
    DateTime? ratedAt,
    SessionClip? clip,
    bool clearRating = false,
    bool clearClip = false,
  }) {
    return SessionRatingState(
      phase: phase ?? this.phase,
      stars: clearRating ? null : (stars ?? this.stars),
      lobbyId: clearRating ? null : (lobbyId ?? this.lobbyId),
      raterUid: clearRating ? null : (raterUid ?? this.raterUid),
      matchId: clearRating ? null : (matchId ?? this.matchId),
      gameName: clearRating ? null : (gameName ?? this.gameName),
      result: clearRating ? null : (result ?? this.result),
      comment: clearRating ? null : (comment ?? this.comment),
      ratedAt: clearRating ? null : (ratedAt ?? this.ratedAt),
      clip: clearRating || clearClip ? null : (clip ?? this.clip),
    );
  }
}

bool isValidSessionStars(int? stars) =>
    stars != null && stars >= 1 && stars <= 5;

/// Reduce a session-rating snapshot. Pure; no I/O.
SessionRatingState reduceSessionRating({
  required SessionRatingState current,
  required SessionRatingEvent event,
  int? stars,
  String? lobbyId,
  String? raterUid,
  String? matchId,
  String? gameName,
  String? result,
  String? comment,
  DateTime? ratedAt,
  SessionClip? clip,
}) {
  switch (event) {
    case SessionRatingEvent.rate:
      if (!isValidSessionStars(stars)) return current;
      return SessionRatingState(
        phase: SessionRatingPhase.rated,
        stars: stars,
        lobbyId: lobbyId ?? current.lobbyId,
        raterUid: raterUid ?? current.raterUid,
        matchId: matchId ?? current.matchId,
        gameName: gameName ?? current.gameName,
        result: result ?? current.result,
        comment: comment ?? current.comment,
        ratedAt: ratedAt ?? current.ratedAt ?? DateTime.now().toUtc(),
        clip: clip ?? current.clip,
      );

    case SessionRatingEvent.skip:
      if (current.phase == SessionRatingPhase.rated) return current;
      return SessionRatingState(
        phase: SessionRatingPhase.skipped,
        lobbyId: lobbyId ?? current.lobbyId,
        raterUid: raterUid ?? current.raterUid,
        matchId: matchId ?? current.matchId,
        gameName: gameName ?? current.gameName,
        result: result ?? current.result,
      );

    case SessionRatingEvent.clear:
      return SessionRatingState.unrated;
  }
}

/// Reduce a session-clip snapshot. Pure; no I/O. Attach requires a clip id.
SessionClip reduceSessionClip({
  required SessionClip current,
  required SessionClipEvent event,
  String? clipId,
  String? videoUrl,
  String? thumbUrl,
  int? durationMs,
  String? title,
  String? fileName,
  String? source,
  DateTime? attachedAt,
}) {
  switch (event) {
    case SessionClipEvent.attach:
      final id = _nonEmpty(clipId) ?? _nonEmpty(current.clipId);
      if (id == null) return current;
      return SessionClip(
        clipId: id,
        videoUrl: _nonEmpty(videoUrl) ?? current.videoUrl,
        thumbUrl: _nonEmpty(thumbUrl) ?? current.thumbUrl,
        durationMs: durationMs ?? current.durationMs,
        title: _nonEmpty(title) ?? current.title,
        fileName: _nonEmpty(fileName) ?? current.fileName,
        source: _nonEmpty(source) ?? current.source ?? kSessionClipGallerySource,
        attachedAt: attachedAt ?? current.attachedAt ?? DateTime.now().toUtc(),
      );

    case SessionClipEvent.skip:
      if (current.isAttached) return current;
      return SessionClip.empty;

    case SessionClipEvent.clear:
      return SessionClip.empty;
  }
}

/// Stamp [clip] onto a rated session. No-op unless the session is rated and
/// the clip is attached. Live path: [promptAndRecordEndedSession].
SessionRatingState attachClipToRatedSession(
  SessionRatingState rating,
  SessionClip clip,
) {
  if (!rating.isRated || !clip.isAttached) return rating;
  return rating.copyWith(clip: clip);
}

const kSessionRatingNotesKey = 'session_rating';
const kSessionClipNotesKey = 'session_clip';
const kSessionClipGallerySource = 'gallery';

/// JSON for `match_history.notes`. Keeps any prior plain-text notes under
/// `text` so a rating write does not smash a human note. Clip metadata sits
/// alongside [kSessionRatingNotesKey] when attached.
String encodeSessionRatingNotes(
  SessionRatingState rating, {
  dynamic existingNotes,
}) {
  final payload = _notesObject(existingNotes);
  payload[kSessionRatingNotesKey] = <String, dynamic>{
    'v': 1,
    'stars': rating.stars,
    if (_nonEmpty(rating.raterUid) != null) 'rater_uid': rating.raterUid,
    if (_nonEmpty(rating.lobbyId) != null) 'lobby_id': rating.lobbyId,
    if (_nonEmpty(rating.matchId) != null) 'match_id': rating.matchId,
    if (_nonEmpty(rating.gameName) != null) 'game_name': rating.gameName,
    if (_nonEmpty(rating.result) != null) 'result': rating.result,
    if (_nonEmpty(rating.comment) != null) 'comment': rating.comment,
    'rated_at':
        (rating.ratedAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
  };
  if (rating.hasClip) {
    return encodeSessionClipNotes(rating.clip!, existingNotes: payload);
  }
  return jsonEncode(payload);
}

/// Merge clip metadata into `match_history.notes` without dropping a rating.
String encodeSessionClipNotes(
  SessionClip clip, {
  dynamic existingNotes,
}) {
  final payload = _notesObject(existingNotes);
  if (!clip.isAttached) return jsonEncode(payload);
  payload[kSessionClipNotesKey] = sessionClipPayload(clip);
  return jsonEncode(payload);
}

Map<String, dynamic> sessionClipPayload(SessionClip clip) {
  return <String, dynamic>{
    'v': 1,
    'clip_id': clip.clipId,
    if (_nonEmpty(clip.videoUrl) != null) 'video_url': clip.videoUrl,
    if (_nonEmpty(clip.thumbUrl) != null) 'thumb_url': clip.thumbUrl,
    if (clip.durationMs != null) 'duration_ms': clip.durationMs,
    if (_nonEmpty(clip.title) != null) 'title': clip.title,
    if (_nonEmpty(clip.fileName) != null) 'file_name': clip.fileName,
    if (_nonEmpty(clip.source) != null) 'source': clip.source,
    'attached_at':
        (clip.attachedAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
  };
}

/// Null unless [rating] is a 1–5 star submit.
String? notesForSessionRating(
  SessionRatingState rating, {
  dynamic existingNotes,
}) {
  if (!rating.isRated) return null;
  return encodeSessionRatingNotes(rating, existingNotes: existingNotes);
}

/// Reads a session rating out of `match_history.notes` (JSON or map).
SessionRatingState? decodeSessionRatingFromNotes(
  dynamic notes, {
  String? lobbyId,
  String? matchId,
  String? gameName,
  String? result,
}) {
  final payload = _notesObject(notes);
  if (payload.isEmpty) return null;
  final raw = payload[kSessionRatingNotesKey] ?? payload['sessionRating'];
  Map<String, dynamic>? nested;
  if (raw is Map) {
    nested = Map<String, dynamic>.from(raw);
  } else if (payload.containsKey('stars') && payload['stars'] != null) {
    nested = payload;
  }
  if (nested == null) return null;
  final stars = _asInt(nested['stars']);
  if (!isValidSessionStars(stars)) return null;
  return SessionRatingState(
    phase: SessionRatingPhase.rated,
    stars: stars,
    lobbyId: _nonEmpty(nested['lobby_id']?.toString()) ?? lobbyId,
    raterUid: _nonEmpty(nested['rater_uid']?.toString()) ??
        _nonEmpty(nested['raterUid']?.toString()),
    matchId: _nonEmpty(nested['match_id']?.toString()) ??
        _nonEmpty(nested['matchId']?.toString()) ??
        matchId,
    gameName: _nonEmpty(nested['game_name']?.toString()) ??
        _nonEmpty(nested['gameName']?.toString()) ??
        gameName,
    result: _nonEmpty(nested['result']?.toString()) ?? result,
    comment: _nonEmpty(nested['comment']?.toString()),
    ratedAt: _asDateTime(nested['rated_at'] ?? nested['ratedAt']),
    clip: decodeSessionClipFromNotes(payload),
  );
}

/// Reads clip metadata out of `match_history.notes` (JSON or map).
SessionClip? decodeSessionClipFromNotes(dynamic notes) {
  final payload = notes is Map<String, dynamic>
      ? notes
      : _notesObject(notes);
  if (payload.isEmpty) return null;
  final raw = payload[kSessionClipNotesKey] ?? payload['sessionClip'];
  if (raw is! Map) return null;
  final nested = Map<String, dynamic>.from(raw);
  final clipId = _nonEmpty(nested['clip_id']?.toString()) ??
      _nonEmpty(nested['clipId']?.toString());
  if (clipId == null) return null;
  return SessionClip(
    clipId: clipId,
    videoUrl: _nonEmpty(nested['video_url']?.toString()) ??
        _nonEmpty(nested['videoUrl']?.toString()),
    thumbUrl: _nonEmpty(nested['thumb_url']?.toString()) ??
        _nonEmpty(nested['thumbUrl']?.toString()) ??
        _nonEmpty(nested['thumbnail_url']?.toString()),
    durationMs: _asInt(nested['duration_ms'] ?? nested['durationMs'] ?? nested['duration']),
    title: _nonEmpty(nested['title']?.toString()),
    fileName: _nonEmpty(nested['file_name']?.toString()) ??
        _nonEmpty(nested['fileName']?.toString()),
    source: _nonEmpty(nested['source']?.toString()),
    attachedAt: _asDateTime(nested['attached_at'] ?? nested['attachedAt']),
  );
}

/// Stamp [rating] onto a `match_history` / gameHistory row via `notes`.
Map<String, dynamic> applySessionRatingToMatchRow({
  required Map<String, dynamic> row,
  required SessionRatingState rating,
}) {
  final next = Map<String, dynamic>.from(row);
  if (!rating.isRated) return next;
  next['notes'] = encodeSessionRatingNotes(
    rating,
    existingNotes: row['notes'],
  );
  return next;
}

SessionRatingState? sessionRatingFromMatchRow(Map<String, dynamic> row) {
  return decodeSessionRatingFromNotes(
    row['notes'],
    lobbyId: row['lobby_id']?.toString() ?? row['lobbyId']?.toString(),
    matchId: row['id']?.toString() ?? row['match_id']?.toString(),
    gameName: row['game_name']?.toString() ?? row['gameName']?.toString(),
    result: row['result']?.toString(),
  );
}

class SessionRatingAverages {
  const SessionRatingAverages({
    this.dailyAverage,
    this.allTimeAverage,
    this.dailySampleSize = 0,
    this.allTimeSampleSize = 0,
  });

  final double? dailyAverage;
  final double? allTimeAverage;
  final int dailySampleSize;
  final int allTimeSampleSize;

  bool get isEmpty => dailyAverage == null && allTimeAverage == null;
}

const kLastFiveRatedSessionsLimit = 5;

const _kLastFiveMonthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Newest [limit] rated sessions from `match_history` rows.
///
/// Skips unrated / skipped / plain-text notes. Sorts by `rated_at`, then
/// row `created_at`. Live path: [StatsDashboardSnapshot.fromSources].
List<SessionRatingState> lastFiveRatedSessionsFromHistory(
  List<Map<String, dynamic>> rows, {
  int limit = kLastFiveRatedSessionsLimit,
}) {
  final cap = limit < 0 ? 0 : limit;
  if (cap == 0 || rows.isEmpty) return const [];

  final rated = <SessionRatingState>[];
  for (final row in rows) {
    final rating = sessionRatingFromMatchRow(row);
    if (rating == null || !rating.isRated) continue;
    if (rating.ratedAt != null) {
      rated.add(rating);
      continue;
    }
    final when = _asDateTime(row['created_at'] ?? row['createdAt'])?.toUtc();
    rated.add(when == null ? rating : rating.copyWith(ratedAt: when));
  }
  rated.sort((a, b) {
    final aMs = a.ratedAt?.toUtc().millisecondsSinceEpoch ?? 0;
    final bMs = b.ratedAt?.toUtc().millisecondsSinceEpoch ?? 0;
    return bMs.compareTo(aMs);
  });
  if (rated.length <= cap) return List<SessionRatingState>.from(rated);
  return rated.sublist(0, cap);
}

/// Compact You / stats line: `4★ · Warzone · Win · Sep 3 · Clip`.
String lastFiveRatedSessionLabel(SessionRatingState rating) {
  final parts = <String>[];
  if (isValidSessionStars(rating.stars)) {
    parts.add('${rating.stars}★');
  }
  final game = rating.gameName?.trim();
  if (game != null && game.isNotEmpty) parts.add(game);
  final result = lastFiveRatedSessionResultLabel(rating.result);
  if (result != null) parts.add(result);
  final date = lastFiveRatedSessionDateLabel(rating.ratedAt);
  if (date.isNotEmpty) parts.add(date);
  if (rating.hasClip) parts.add('Clip');
  return parts.join(' · ');
}

String? lastFiveRatedSessionResultLabel(String? result) {
  switch (result?.toLowerCase().trim()) {
    case 'win':
    case 'won':
    case 'victory':
    case 'w':
      return 'Win';
    case 'loss':
    case 'lost':
    case 'defeat':
    case 'l':
      return 'Loss';
    case 'draw':
    case 'tie':
    case 'd':
      return 'Draw';
    default:
      return null;
  }
}

String lastFiveRatedSessionDateLabel(DateTime? at) {
  if (at == null) return '';
  final utc = at.toUtc();
  return '${_kLastFiveMonthLabels[utc.month - 1]} ${utc.day}';
}

/// Daily = rated in the last 24h; all-time = every decoded session rating.
SessionRatingAverages sessionRatingAveragesFromHistory(
  List<Map<String, dynamic>> rows, {
  DateTime? now,
}) {
  final clock = (now ?? DateTime.now()).toUtc();
  final cutoff = clock.subtract(const Duration(hours: 24));
  var dailyTotal = 0;
  var dailyCount = 0;
  var allTotal = 0;
  var allCount = 0;
  for (final row in rows) {
    final rating = sessionRatingFromMatchRow(row);
    if (rating == null || !rating.isRated) continue;
    final stars = rating.stars!;
    allTotal += stars;
    allCount++;
    final when = rating.ratedAt?.toUtc() ??
        _asDateTime(row['created_at'] ?? row['createdAt'])?.toUtc();
    if (when != null && !when.isBefore(cutoff)) {
      dailyTotal += stars;
      dailyCount++;
    }
  }
  return SessionRatingAverages(
    dailyAverage: dailyCount == 0 ? null : dailyTotal / dailyCount,
    allTimeAverage: allCount == 0 ? null : allTotal / allCount,
    dailySampleSize: dailyCount,
    allTimeSampleSize: allCount,
  );
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

String? _nonEmpty(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return num.tryParse(value.trim())?.toInt();
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String sessionRecordedSnackbar(String result, SessionRatingState rating) {
  final outcome = result == 'win' ? 'Win' : 'Loss';
  if (rating.isRated) {
    final clip = rating.hasClip ? ' · clip' : '';
    return '$outcome recorded · ${rating.stars}★$clip';
  }
  return '$outcome recorded';
}
