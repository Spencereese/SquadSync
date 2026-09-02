import '../domain/entities/app_user.dart';
import '../domain/entities/lobby.dart';
import '../domain/entities/lobby_state.dart';

/// One squad member's current streak for the Stats dashboard bar chart.
class SquadMemberStreak {
  const SquadMemberStreak({
    required this.id,
    required this.label,
    required this.streak,
  });

  final String id;
  final String label;
  final int streak;

  String get shortLabel {
    if (label.length <= 8) return label;
    return '${label.substring(0, 7)}…';
  }
}

/// Win / loss / draw totals from `get_lobby_stats` or match-history rows.
class WinLossSummary {
  const WinLossSummary({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  final int wins;
  final int losses;
  final int draws;

  int get decided => wins + losses;
  int get total => wins + losses + draws;
  bool get isEmpty => total == 0;

  double get winRate {
    if (decided == 0) return 0;
    return wins / decided;
  }

  WinLossSummary operator +(WinLossSummary other) {
    return WinLossSummary(
      wins: wins + other.wins,
      losses: losses + other.losses,
      draws: draws + other.draws,
    );
  }
}

/// Compact community standing pulled from [AppUser] (complaints, bans, friends).
class CommunitySummary {
  const CommunitySummary({
    this.complaints = 0,
    this.bans = 0,
    this.friends = 0,
    this.gameAverages = const [],
  });

  final int complaints;
  final int bans;
  final int friends;
  final List<GameRatingAverage> gameAverages;

  bool get isEmpty =>
      complaints == 0 && bans == 0 && friends == 0 && gameAverages.isEmpty;
}

/// Per-game all-time rating average for the community section.
class GameRatingAverage {
  const GameRatingAverage({
    required this.gameName,
    required this.average,
    required this.sampleSize,
  });

  final String gameName;
  final double average;
  final int sampleSize;
}

/// Averaged daily and all-time ratings from nested game → player maps.
class RatingSummary {
  const RatingSummary({
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

  static String format(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(1)}★';
  }
}

/// Snapshot the Stats dashboard renders. Built from user, lobby, and remote match stats.
class StatsDashboardSnapshot {
  const StatsDashboardSnapshot({
    required this.memberStreaks,
    required this.winLoss,
    required this.ratings,
    this.community = const CommunitySummary(),
  });

  final List<SquadMemberStreak> memberStreaks;
  final WinLossSummary winLoss;
  final RatingSummary ratings;
  final CommunitySummary community;

  bool get hasStreaks => memberStreaks.any((m) => m.streak > 0);

  factory StatsDashboardSnapshot.fromSources({
    AppUser? user,
    LobbyState? lobby,
    List<Map<String, dynamic>> extraHistory = const [],
    WinLossSummary? remoteWinLoss,
  }) {
    final lobbyState = lobby ?? LobbyState.initial();
    final remote = extraHistory.map(normalizeMatchHistoryRow).toList();
    final history = remote.isNotEmpty
        ? remote
        : List<Map<String, dynamic>>.from(lobbyState.gameHistory);

    final daily = user != null && user.dailyRatings.isNotEmpty
        ? user.dailyRatings
        : lobbyState.dailyRatings;
    final allTime = user != null && user.allTimeRatings.isNotEmpty
        ? user.allTimeRatings
        : lobbyState.allTimeRatings;
    final streaks = user?.currentStreaks ?? const <String, int>{};

    final fromRemoteStats = remoteWinLoss;
    final winLoss = (fromRemoteStats != null && !fromRemoteStats.isEmpty)
        ? fromRemoteStats
        : winLossFromGameHistory(history);

    return StatsDashboardSnapshot(
      memberStreaks: buildMemberStreaks(
        memberUids: squadMemberUids(lobbyState, currentUid: user?.uid),
        displayNames: lobbyState.memberDisplayNames,
        currentStreaks: streaks,
        gameHistory: history,
        currentUserId: user?.uid,
        currentUserName: user?.displayName,
      ),
      winLoss: winLoss,
      ratings: ratingSummaryFrom(daily, allTime),
      community: communitySummaryFrom(user),
    );
  }
}

/// Lobby ids whose `get_lobby_stats` / `match_history` rows feed the dashboard.
List<String> lobbyIdsForStats(LobbyState lobby) {
  final selected = lobby.selectedLobbyId;
  if (selected != null && selected.isNotEmpty) return [selected];
  final currentId = lobby.currentLobby?.id;
  if (currentId != null && currentId.isNotEmpty) return [currentId];
  if (lobby.userLobbies.isNotEmpty) {
    return lobby.userLobbies.keys.where((id) => id.isNotEmpty).toList();
  }
  return lobby.userLobbyIds.where((id) => id.isNotEmpty).toList();
}

/// Loads W/L from `get_lobby_stats` and streaks from `match_history` rows.
///
/// `LobbyState.gameHistory` stays empty unless the notifier appends a row after
/// recording; the dashboard therefore fetches remote stats instead of that list.
Future<StatsDashboardSnapshot> loadStatsDashboardSnapshot({
  AppUser? user,
  required LobbyState lobby,
  required Future<Map<String, dynamic>> Function(String lobbyId)
      fetchLobbyStats,
  required Future<List<Map<String, dynamic>>> Function(String lobbyId)
      fetchMatchHistory,
}) async {
  final ids = lobbyIdsForStats(lobby);
  if (ids.isEmpty) {
    return StatsDashboardSnapshot.fromSources(user: user, lobby: lobby);
  }

  final statsList = await Future.wait(ids.map((id) async {
    try {
      return winLossFromLobbyStats(await fetchLobbyStats(id));
    } catch (_) {
      return const WinLossSummary();
    }
  }));
  final historyLists = await Future.wait(ids.map((id) async {
    try {
      return await fetchMatchHistory(id);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }));

  var remoteWinLoss = const WinLossSummary();
  for (final part in statsList) {
    remoteWinLoss += part;
  }

  return StatsDashboardSnapshot.fromSources(
    user: user,
    lobby: lobby,
    extraHistory: historyLists.expand((rows) => rows).toList(),
    remoteWinLoss: remoteWinLoss,
  );
}

/// Parses the `get_lobby_stats` RPC row (`wins`, `losses`, `draws`, `win_rate`).
///
/// Postgres BIGINT / NUMERIC values may arrive as [int], [num], or [String].
/// `win_rate` is a 0–100 percentage in SQL; [WinLossSummary.winRate] is derived
/// from counts so the pie chart does not treat 66.7 as 6670%.
WinLossSummary winLossFromLobbyStats(Map<String, dynamic>? stats) {
  if (stats == null || stats.isEmpty) return const WinLossSummary();
  return WinLossSummary(
    wins: _asInt(stats['wins']) ?? 0,
    losses: _asInt(stats['losses']) ?? 0,
    draws: _asInt(stats['draws']) ?? 0,
  );
}

/// Maps a `match_history` row onto the keys the streak / W/L parsers already
/// understand (`result`, `player_uids`, `created_at`).
Map<String, dynamic> normalizeMatchHistoryRow(Map<String, dynamic> row) {
  final out = <String, dynamic>{};
  row.forEach((key, value) {
    out[key.toString()] = value;
  });
  return out;
}

CommunitySummary communitySummaryFrom(AppUser? user) {
  if (user == null) return const CommunitySummary();

  var complaints = 0;
  for (final inner in user.complaints.values) {
    complaints += inner.length;
  }
  var bans = 0;
  for (final list in user.bans.values) {
    bans += list.length;
  }

  final averages = <GameRatingAverage>[];
  for (final entry in user.allTimeRatings.entries) {
    if (entry.value.isEmpty) continue;
    final total =
        entry.value.values.fold<int>(0, (sum, rating) => sum + rating);
    averages.add(
      GameRatingAverage(
        gameName: entry.key,
        average: total / entry.value.length,
        sampleSize: entry.value.length,
      ),
    );
  }
  averages.sort(
    (a, b) => a.gameName.toLowerCase().compareTo(b.gameName.toLowerCase()),
  );

  return CommunitySummary(
    complaints: complaints,
    bans: bans,
    friends: user.friends.length,
    gameAverages: averages,
  );
}

/// Uids for the selected lobby, else the union of the user's lobbies.
List<String> squadMemberUids(LobbyState lobby, {String? currentUid}) {
  final ids = <String>{};

  if (lobby.lobbyMemberUids.isNotEmpty) {
    ids.addAll(lobby.lobbyMemberUids.where((id) => id.isNotEmpty));
  } else {
    final selectedId = lobby.selectedLobbyId;
    final selected = selectedId == null ? null : lobby.userLobbies[selectedId];
    if (selected != null) {
      ids.addAll(selected.memberUids);
    } else {
      for (final Lobby l in lobby.userLobbies.values) {
        ids.addAll(l.memberUids);
      }
    }
  }

  if (currentUid != null && currentUid.isNotEmpty) {
    ids.add(currentUid);
  }
  return ids.toList();
}

List<SquadMemberStreak> buildMemberStreaks({
  required List<String> memberUids,
  required Map<String, String> displayNames,
  required Map<String, int> currentStreaks,
  required List<Map<String, dynamic>> gameHistory,
  String? currentUserId,
  String? currentUserName,
}) {
  final memberKeys = <String>{};
  for (final uid in memberUids) {
    memberKeys.add(uid);
    final name = displayNames[uid];
    if (name != null && name.isNotEmpty) {
      memberKeys.add(name);
      memberKeys.add(name.toLowerCase());
    }
  }
  if (currentUserName != null && currentUserName.isNotEmpty) {
    memberKeys.add(currentUserName);
    memberKeys.add(currentUserName.toLowerCase());
  }

  final streaksMatchMembers = currentStreaks.keys.any(memberKeys.contains);
  final currentUserFallback = (!streaksMatchMembers &&
          currentUserId != null &&
          currentStreaks.isNotEmpty)
      ? currentStreaks.values.reduce((a, b) => a > b ? a : b)
      : null;

  if (memberUids.isEmpty) {
    if (currentStreaks.isEmpty) return const [];
    final fallback = currentStreaks.entries
        .map(
          (e) => SquadMemberStreak(
            id: e.key,
            label: e.key,
            streak: e.value,
          ),
        )
        .toList()
      ..sort(_compareStreaks);
    return fallback;
  }

  final rows = <SquadMemberStreak>[];
  for (final uid in memberUids) {
    final name = displayNames[uid];
    final label = (name != null && name.isNotEmpty)
        ? name
        : (uid == currentUserId &&
                currentUserName != null &&
                currentUserName.isNotEmpty)
            ? currentUserName
            : uid;

    final fromMap = _streakFromMap(
      currentStreaks,
      uid: uid,
      displayName: label,
    );
    final fromHistory = streakFromGameHistory(
      gameHistory,
      memberId: uid,
      displayName: label,
    );

    var streak = fromMap ?? fromHistory ?? 0;
    if (streak == 0 && currentUserFallback != null && uid == currentUserId) {
      streak = currentUserFallback;
    }

    rows.add(SquadMemberStreak(id: uid, label: label, streak: streak));
  }

  rows.sort(_compareStreaks);
  return rows;
}

int _compareStreaks(SquadMemberStreak a, SquadMemberStreak b) {
  final byStreak = b.streak.compareTo(a.streak);
  if (byStreak != 0) return byStreak;
  return a.label.toLowerCase().compareTo(b.label.toLowerCase());
}

int? _streakFromMap(
  Map<String, int> currentStreaks, {
  required String uid,
  required String displayName,
}) {
  final candidates = <String>[uid, displayName, displayName.toLowerCase()];
  for (final key in candidates) {
    final value = currentStreaks[key];
    if (value != null) return value;
  }
  return null;
}

/// Consecutive wins from newest history entry for this member.
int? streakFromGameHistory(
  List<Map<String, dynamic>> gameHistory, {
  required String memberId,
  String? displayName,
}) {
  if (gameHistory.isEmpty) return null;

  final sorted = List<Map<String, dynamic>>.from(gameHistory)
    ..sort((a, b) {
      final ta = _timestampOf(a);
      final tb = _timestampOf(b);
      if (ta != null && tb != null) return tb.compareTo(ta);
      if (ta != null) return -1;
      if (tb != null) return 1;
      return 0;
    });

  var streak = 0;
  var sawResult = false;
  for (final entry in sorted) {
    final players = _playersOf(entry);
    // Missing player_uids must not credit every squad member.
    if (players.isEmpty) continue;
    final involved = players.contains(memberId) ||
        (displayName != null && players.contains(displayName));
    if (!involved) continue;

    final result = _resultOf(entry);
    if (result == null) continue;
    sawResult = true;
    if (result == 'win') {
      streak++;
    } else {
      break;
    }
  }

  if (!sawResult) return null;
  return streak;
}

WinLossSummary winLossFromGameHistory(List<Map<String, dynamic>> gameHistory) {
  var wins = 0;
  var losses = 0;
  var draws = 0;

  for (final entry in gameHistory) {
    final countedWins = _asInt(entry['wins']);
    final countedLosses = _asInt(entry['losses']);
    final countedDraws = _asInt(entry['draws']);
    if (countedWins != null || countedLosses != null || countedDraws != null) {
      wins += countedWins ?? 0;
      losses += countedLosses ?? 0;
      draws += countedDraws ?? 0;
      continue;
    }

    switch (_resultOf(entry)) {
      case 'win':
        wins++;
      case 'loss':
        losses++;
      case 'draw':
        draws++;
      default:
        break;
    }
  }

  return WinLossSummary(wins: wins, losses: losses, draws: draws);
}

RatingSummary ratingSummaryFrom(
  Map<String, Map<String, int>> daily,
  Map<String, Map<String, int>> allTime,
) {
  final dailyAgg = _averageNested(daily);
  final allTimeAgg = _averageNested(allTime);
  return RatingSummary(
    dailyAverage: dailyAgg.$1,
    allTimeAverage: allTimeAgg.$1,
    dailySampleSize: dailyAgg.$2,
    allTimeSampleSize: allTimeAgg.$2,
  );
}

(double?, int) _averageNested(Map<String, Map<String, int>> nested) {
  var total = 0;
  var count = 0;
  for (final inner in nested.values) {
    for (final rating in inner.values) {
      total += rating;
      count++;
    }
  }
  if (count == 0) return (null, 0);
  return (total / count, count);
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return num.tryParse(value.trim())?.toInt();
  return null;
}

DateTime? _timestampOf(Map<String, dynamic> entry) {
  for (final key in [
    'timestamp',
    'lastPlayedAt',
    'created_at',
    'createdAt',
    'playedAt',
  ]) {
    final value = entry[key];
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      if (value > 9999999999) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
  }
  return null;
}

String? _resultOf(Map<String, dynamic> entry) {
  if (entry['won'] == true || entry['isWin'] == true) return 'win';
  if (entry['won'] == false || entry['isWin'] == false) return 'loss';

  final raw = entry['result'] ??
      entry['outcome'] ??
      entry['winLoss'] ??
      entry['win_loss'];
  if (raw is bool) return raw ? 'win' : 'loss';
  if (raw == null) return null;

  switch (raw.toString().toLowerCase().trim()) {
    case 'win':
    case 'won':
    case 'victory':
    case 'w':
      return 'win';
    case 'loss':
    case 'lost':
    case 'defeat':
    case 'l':
      return 'loss';
    case 'draw':
    case 'tie':
    case 'd':
      return 'draw';
    default:
      return null;
  }
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
  for (final key in ['uid', 'userId', 'user_id', 'player']) {
    final value = entry[key];
    if (value is String && value.isNotEmpty) return [value];
  }
  return const [];
}

/// `player_uids` arrives as a JSON list, or occasionally a Postgres `{a,b}` literal.
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
