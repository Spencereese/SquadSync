import 'dart:convert';

/// 1–5 star rating of a squad session after it ends.
///
/// Persistence is the existing `match_history.notes` TEXT column (JSON),
/// not a new table. The reducer and write-plan are pure; I/O lives in
/// [LobbyNotifier] / `LobbyRemoteDataSourceImpl` (injected SupabaseClient).
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

/// End-session sheet categories (1–5 each). Encoded into `match_history.notes`.
const kSessionRatingCategoryLabels = ['Vibes', 'Comms', 'Gunny', 'Wingman'];
const kSessionRatingVibesKey = 'vibes';
const kSessionRatingCommsKey = 'comms';
const kSessionRatingGunnyKey = 'gunny';
const kSessionRatingWingmanKey = 'wingman';

/// Snapshot of one user's rating of one ended squad session.
class SessionRatingState {
  const SessionRatingState({
    this.phase = SessionRatingPhase.unrated,
    this.stars,
    this.vibes,
    this.comms,
    this.gunny,
    this.wingman,
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
  final int? vibes;
  final int? comms;
  final int? gunny;
  final int? wingman;
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

  bool get hasCategoryScores =>
      isValidSessionStars(vibes) ||
      isValidSessionStars(comms) ||
      isValidSessionStars(gunny) ||
      isValidSessionStars(wingman);

  bool get hasClip => clip != null && clip!.isAttached;

  /// Label → 1–5 for filled sheet categories.
  Map<String, int> get categoryScores => {
        if (isValidSessionStars(vibes)) 'Vibes': vibes!,
        if (isValidSessionStars(comms)) 'Comms': comms!,
        if (isValidSessionStars(gunny)) 'Gunny': gunny!,
        if (isValidSessionStars(wingman)) 'Wingman': wingman!,
      };

  SessionRatingState copyWith({
    SessionRatingPhase? phase,
    int? stars,
    int? vibes,
    int? comms,
    int? gunny,
    int? wingman,
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
      vibes: clearRating ? null : (vibes ?? this.vibes),
      comms: clearRating ? null : (comms ?? this.comms),
      gunny: clearRating ? null : (gunny ?? this.gunny),
      wingman: clearRating ? null : (wingman ?? this.wingman),
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

/// Overall stars, or the rounded average of filled Vibes/Comms/Gunny/Wingman.
int? sessionStarsFromSheet({
  int? stars,
  int? vibes,
  int? comms,
  int? gunny,
  int? wingman,
}) {
  if (isValidSessionStars(stars)) return stars;
  final values = <int>[
    if (isValidSessionStars(vibes)) vibes!,
    if (isValidSessionStars(comms)) comms!,
    if (isValidSessionStars(gunny)) gunny!,
    if (isValidSessionStars(wingman)) wingman!,
  ];
  if (values.isEmpty) return null;
  return (values.reduce((a, b) => a + b) / values.length).round().clamp(1, 5);
}

int? _keepCategory(int? incoming, int? current) {
  if (isValidSessionStars(incoming)) return incoming;
  if (isValidSessionStars(current)) return current;
  return null;
}

/// Reduce a session-rating snapshot. Pure; no I/O.
SessionRatingState reduceSessionRating({
  required SessionRatingState current,
  required SessionRatingEvent event,
  int? stars,
  int? vibes,
  int? comms,
  int? gunny,
  int? wingman,
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
      final nextVibes = _keepCategory(vibes, current.vibes);
      final nextComms = _keepCategory(comms, current.comms);
      final nextGunny = _keepCategory(gunny, current.gunny);
      final nextWingman = _keepCategory(wingman, current.wingman);
      final nextStars = sessionStarsFromSheet(
        stars: stars,
        vibes: nextVibes,
        comms: nextComms,
        gunny: nextGunny,
        wingman: nextWingman,
      );
      if (nextStars == null) return current;
      return SessionRatingState(
        phase: SessionRatingPhase.rated,
        stars: nextStars,
        vibes: nextVibes,
        comms: nextComms,
        gunny: nextGunny,
        wingman: nextWingman,
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
        comment: comment ?? current.comment,
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
    if (isValidSessionStars(rating.vibes)) kSessionRatingVibesKey: rating.vibes,
    if (isValidSessionStars(rating.comms)) kSessionRatingCommsKey: rating.comms,
    if (isValidSessionStars(rating.gunny)) kSessionRatingGunnyKey: rating.gunny,
    if (isValidSessionStars(rating.wingman))
      kSessionRatingWingmanKey: rating.wingman,
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

/// Stored gallery path / http URL You/stats can open. Null if missing.
String? sessionClipMediaUrl(SessionClip? clip) {
  if (clip == null || !clip.isAttached) return null;
  return _nonEmpty(clip.videoUrl);
}

bool canOpenSessionClip(SessionClip? clip) =>
    sessionClipMediaUrl(clip) != null;

/// Parse ticket-9 `video_url` (gallery path or http) into a media URI.
Uri? sessionClipMediaUri(SessionClip? clip) {
  final url = sessionClipMediaUrl(clip);
  if (url == null) return null;
  return uriForSessionClipMedia(url);
}

Uri? uriForSessionClipMedia(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme) return parsed;
  if (trimmed.startsWith('/')) {
    return Uri(scheme: 'file', path: trimmed);
  }
  return parsed;
}

bool sessionClipIsNetworkMedia(SessionClip? clip) {
  final uri = sessionClipMediaUri(clip);
  if (uri == null) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}

/// Dialog / a11y title for an attached session clip.
String sessionClipPlaybackTitle(SessionClip clip) {
  return _nonEmpty(clip.title) ??
      _nonEmpty(clip.fileName) ??
      'Session clip';
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
  final vibes = _categoryOf(nested, kSessionRatingVibesKey, 'Vibes');
  final comms = _categoryOf(nested, kSessionRatingCommsKey, 'Comms');
  final gunny = _categoryOf(nested, kSessionRatingGunnyKey, 'Gunny');
  final wingman = _categoryOf(nested, kSessionRatingWingmanKey, 'Wingman');
  final resolvedStars = sessionStarsFromSheet(
    stars: stars,
    vibes: vibes,
    comms: comms,
    gunny: gunny,
    wingman: wingman,
  );
  if (!isValidSessionStars(resolvedStars)) return null;
  return SessionRatingState(
    phase: SessionRatingPhase.rated,
    stars: resolvedStars,
    vibes: vibes,
    comms: comms,
    gunny: gunny,
    wingman: wingman,
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
    comment: _nonEmpty(nested['comment']?.toString()) ??
        _nonEmpty(nested['notes']?.toString()) ??
        _nonEmpty(payload['text']?.toString()),
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

const kMatchHistoryTable = 'match_history';
const kMatchHistoryUpdateWindow = Duration(minutes: 10);

enum SessionRatingWriteKind { create, update }

/// Insert or update payload for existing `match_history` (no new table).
class SessionRatingWrite {
  const SessionRatingWrite.create(this.payload)
      : kind = SessionRatingWriteKind.create,
        matchId = null;

  const SessionRatingWrite.update({
    required this.matchId,
    required this.payload,
  }) : kind = SessionRatingWriteKind.update;

  final SessionRatingWriteKind kind;
  final String? matchId;
  final Map<String, dynamic> payload;

  bool get isUpdate => kind == SessionRatingWriteKind.update;
  bool get isCreate => kind == SessionRatingWriteKind.create;
}

/// True when [row] is still inside the match_history UPDATE RLS window.
bool isRecentMatchHistoryRow(
  Map<String, dynamic> row, {
  DateTime? now,
  Duration window = kMatchHistoryUpdateWindow,
}) {
  final created = _asDateTime(row['created_at'] ?? row['createdAt'])?.toUtc();
  if (created == null) return false;
  final clock = (now ?? DateTime.now()).toUtc();
  final age = clock.difference(created);
  return !age.isNegative && age <= window;
}

String? matchHistoryRowId(Map<String, dynamic>? row) {
  final id = row?['id']?.toString().trim();
  if (id == null || id.isEmpty) return null;
  return id;
}

/// Create vs update for an ended-session write. Pure; no I/O.
///
/// Update when a recent `match_history` row exists for this lobby (10-minute
/// creator window). Skip/unrated updates do not smash existing notes.
SessionRatingWrite planMatchHistoryWrite({
  required String lobbyId,
  required String gameName,
  required String result,
  required List<String> playerUids,
  required String createdBy,
  String? notes,
  Map<String, dynamic>? existingRow,
  DateTime? now,
}) {
  final existingId = matchHistoryRowId(existingRow);
  final canUpdate = existingRow != null &&
      existingId != null &&
      isRecentMatchHistoryRow(existingRow, now: now);
  if (canUpdate) {
    final payload = <String, dynamic>{
      'game_name': gameName,
      'result': result,
      'player_uids': List<String>.from(playerUids),
    };
    final merged = mergeMatchHistoryNotes(
      incomingNotes: notes,
      existingNotes: existingRow['notes'],
    );
    if (merged != null) payload['notes'] = merged;
    return SessionRatingWrite.update(matchId: existingId, payload: payload);
  }
  return SessionRatingWrite.create(<String, dynamic>{
    'lobby_id': lobbyId,
    'game_name': gameName,
    'result': result,
    'player_uids': List<String>.from(playerUids),
    'created_by': createdBy,
    'notes': notes,
  });
}

/// Stamp a new rating onto existing notes. Null incoming leaves existing as-is.
String? mergeMatchHistoryNotes({
  String? incomingNotes,
  dynamic existingNotes,
}) {
  if (incomingNotes == null || incomingNotes.trim().isEmpty) {
    if (existingNotes == null) return null;
    if (existingNotes is String) return existingNotes;
    return jsonEncode(_notesObject(existingNotes));
  }
  final incoming = decodeSessionRatingFromNotes(incomingNotes);
  if (incoming == null || !incoming.isRated) return incomingNotes;
  return encodeSessionRatingNotes(incoming, existingNotes: existingNotes);
}

class SessionRatingAverages {
  const SessionRatingAverages({
    this.dailyAverage,
    this.allTimeAverage,
    this.dailySampleSize = 0,
    this.allTimeSampleSize = 0,
    this.vibesAverage,
    this.commsAverage,
    this.gunnyAverage,
    this.wingmanAverage,
    this.vibesSampleSize = 0,
    this.commsSampleSize = 0,
    this.gunnySampleSize = 0,
    this.wingmanSampleSize = 0,
  });

  final double? dailyAverage;
  final double? allTimeAverage;
  final int dailySampleSize;
  final int allTimeSampleSize;
  final double? vibesAverage;
  final double? commsAverage;
  final double? gunnyAverage;
  final double? wingmanAverage;
  final int vibesSampleSize;
  final int commsSampleSize;
  final int gunnySampleSize;
  final int wingmanSampleSize;

  bool get isEmpty => dailyAverage == null && allTimeAverage == null;

  bool get hasCategoryAverages =>
      vibesAverage != null ||
      commsAverage != null ||
      gunnyAverage != null ||
      wingmanAverage != null;
}

const kLastFiveRatedSessionsLimit = 5;
const kLastFiveRatedEmptyCopy = 'No rated sessions yet';
const kLastFiveRatedEmptyHint =
    'Rate Vibes, Comms, Gunny, and Wingman after a match to see them here';
const kLastFiveRatedLoadingCopy = 'Loading session history...';
const kStatsLoadErrorTitle = "Couldn't load stats";
const kStatsLoadErrorBody = 'Session history is unavailable right now.';
const kStatsLoadErrorRetryLabel = 'Retry';
const kYouSessionHistoryErrorCopy = "Couldn't load session history";
const kRatingsEmptyHint = 'No session ratings in match history yet';
const kStreaksEmptyHint = 'Join a lobby to track who is on a streak';

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

/// Compact category line: `V5 · C4 · G3 · W2`. Empty when none filled.
String lastFiveRatedSessionCategoriesLabel(SessionRatingState rating) {
  final parts = <String>[
    if (isValidSessionStars(rating.vibes)) 'V${rating.vibes}',
    if (isValidSessionStars(rating.comms)) 'C${rating.comms}',
    if (isValidSessionStars(rating.gunny)) 'G${rating.gunny}',
    if (isValidSessionStars(rating.wingman)) 'W${rating.wingman}',
  ];
  return parts.join(' · ');
}

/// Optional notes line from ticket-36 `session_rating.comment` / preserved text.
String? lastFiveRatedSessionNotesLabel(SessionRatingState rating) =>
    _nonEmpty(rating.comment);

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
  var vibesTotal = 0;
  var vibesCount = 0;
  var commsTotal = 0;
  var commsCount = 0;
  var gunnyTotal = 0;
  var gunnyCount = 0;
  var wingmanTotal = 0;
  var wingmanCount = 0;
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
    if (isValidSessionStars(rating.vibes)) {
      vibesTotal += rating.vibes!;
      vibesCount++;
    }
    if (isValidSessionStars(rating.comms)) {
      commsTotal += rating.comms!;
      commsCount++;
    }
    if (isValidSessionStars(rating.gunny)) {
      gunnyTotal += rating.gunny!;
      gunnyCount++;
    }
    if (isValidSessionStars(rating.wingman)) {
      wingmanTotal += rating.wingman!;
      wingmanCount++;
    }
  }
  return SessionRatingAverages(
    dailyAverage: dailyCount == 0 ? null : dailyTotal / dailyCount,
    allTimeAverage: allCount == 0 ? null : allTotal / allCount,
    dailySampleSize: dailyCount,
    allTimeSampleSize: allCount,
    vibesAverage: vibesCount == 0 ? null : vibesTotal / vibesCount,
    commsAverage: commsCount == 0 ? null : commsTotal / commsCount,
    gunnyAverage: gunnyCount == 0 ? null : gunnyTotal / gunnyCount,
    wingmanAverage: wingmanCount == 0 ? null : wingmanTotal / wingmanCount,
    vibesSampleSize: vibesCount,
    commsSampleSize: commsCount,
    gunnySampleSize: gunnyCount,
    wingmanSampleSize: wingmanCount,
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

int? _categoryOf(Map<String, dynamic> nested, String snake, String label) {
  final value = _asInt(nested[snake] ?? nested[label] ?? nested[label.toLowerCase()]);
  return isValidSessionStars(value) ? value : null;
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
