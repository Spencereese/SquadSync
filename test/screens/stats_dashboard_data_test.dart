import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/data/lobby_stats_codec.dart';
import 'package:squad_sync/domain/entities/app_user.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/screens/stats_dashboard_data.dart';
import 'package:squad_sync/services/session_rating_machine.dart';

AppUser _user({
  String uid = 'me',
  String? displayName = 'Alex',
  Map<String, int> currentStreaks = const {},
  Map<String, Map<String, int>> dailyRatings = const {},
  Map<String, Map<String, int>> allTimeRatings = const {},
}) {
  return AppUser(
    uid: uid,
    displayName: displayName,
    profileImage: null,
    preferredModes: const {},
    userBlocks: const {},
    pinnedGames: const [],
    notificationSettings: const {},
    hasRatedGame: const {},
    dailyRatings: dailyRatings,
    allTimeRatings: allTimeRatings,
    currentStreaks: currentStreaks,
    complaints: const {},
    bans: const {},
    dailyBanVotes: const {},
    blockedUsers: const [],
    friends: const [],
    alerts: const [],
    userGroups: const [],
    alertCircles: const [],
    publicGroups: const [],
    pinnedMessages: const [],
  );
}

Lobby _lobby({
  required String id,
  required List<String> members,
}) {
  return Lobby.create(
    name: 'Lobby $id',
    gameName: 'Warzone',
    maxSpots: 4,
    createdBy: members.first,
  ).copyWith(id: id, memberUids: members);
}

void main() {
  group('squadMemberUids', () {
    test('prefers lobbyMemberUids when present', () {
      final lobby = LobbyState.initial().copyWith(
        lobbyMemberUids: ['a', 'b'],
        userLobbies: {
          'x': _lobby(id: 'x', members: ['z']),
        },
      );
      expect(squadMemberUids(lobby), ['a', 'b']);
    });

    test('falls back to selected lobby members', () {
      final lobby = LobbyState.initial().copyWith(
        selectedLobbyId: 'x',
        userLobbies: {
          'x': _lobby(id: 'x', members: ['sam', 'kit']),
        },
      );
      expect(squadMemberUids(lobby), ['sam', 'kit']);
    });

    test('resolves selectedLobbyId when it is the lobby chatGroupId', () {
      final lobby = LobbyState.initial().copyWith(
        selectedLobbyId: 'chat-99',
        userLobbies: {
          'lobby-1': _lobby(id: 'lobby-1', members: ['sam', 'kit'])
              .copyWith(chatGroupId: 'chat-99'),
          'lobby-2': _lobby(id: 'lobby-2', members: ['other']),
        },
      );
      expect(squadMemberUids(lobby).toSet(), {'sam', 'kit'});
    });

    test('unions user lobbies when none selected', () {
      final lobby = LobbyState.initial().copyWith(
        userLobbies: {
          'x': _lobby(id: 'x', members: ['a', 'b']),
          'y': _lobby(id: 'y', members: ['b', 'c']),
        },
      );
      expect(squadMemberUids(lobby).toSet(), {'a', 'b', 'c'});
    });

    test('includes current user uid', () {
      final lobby = LobbyState.initial().copyWith(lobbyMemberUids: ['a']);
      expect(squadMemberUids(lobby, currentUid: 'me').toSet(), {'a', 'me'});
    });
  });

  group('buildMemberStreaks', () {
    test('reads currentStreaks keyed by uid', () {
      final rows = buildMemberStreaks(
        memberUids: ['u1', 'u2'],
        displayNames: const {'u1': 'Sam', 'u2': 'Kit'},
        currentStreaks: const {'u1': 4, 'u2': 1},
        gameHistory: const [],
      );
      expect(rows.map((r) => r.label).toList(), ['Sam', 'Kit']);
      expect(rows.map((r) => r.streak).toList(), [4, 1]);
    });

    test('reads currentStreaks keyed by display name', () {
      final rows = buildMemberStreaks(
        memberUids: ['u1'],
        displayNames: const {'u1': 'Sam'},
        currentStreaks: const {'Sam': 7},
        gameHistory: const [],
      );
      expect(rows.single.streak, 7);
    });

    test('falls back to currentStreaks keys when there are no members', () {
      final rows = buildMemberStreaks(
        memberUids: const [],
        displayNames: const {},
        currentStreaks: const {'Warzone': 3, 'BF6': 1},
        gameHistory: const [],
      );
      expect(rows.map((r) => r.id).toList(), ['Warzone', 'BF6']);
      expect(rows.first.streak, 3);
    });

    test('uses max game streak for current user when keys are games', () {
      final rows = buildMemberStreaks(
        memberUids: ['me', 'u2'],
        displayNames: const {'me': 'Alex', 'u2': 'Kit'},
        currentStreaks: const {'Warzone': 5, 'BF6': 2},
        gameHistory: const [],
        currentUserId: 'me',
        currentUserName: 'Alex',
      );
      final byId = {for (final r in rows) r.id: r.streak};
      expect(byId['me'], 5);
      expect(byId['u2'], 0);
    });

    test('derives consecutive wins from newest gameHistory', () {
      final history = [
        {
          'result': 'win',
          'player_uids': ['u1'],
          'timestamp': '2026-09-01T12:00:00Z',
        },
        {
          'result': 'win',
          'player_uids': ['u1'],
          'timestamp': '2026-08-31T12:00:00Z',
        },
        {
          'result': 'loss',
          'player_uids': ['u1'],
          'timestamp': '2026-08-30T12:00:00Z',
        },
      ];
      final rows = buildMemberStreaks(
        memberUids: ['u1'],
        displayNames: const {'u1': 'Sam'},
        currentStreaks: const {},
        gameHistory: history,
      );
      expect(rows.single.streak, 2);
    });

    test('skips games the member was not in', () {
      final history = [
        {
          'result': 'loss',
          'player_uids': ['other'],
          'timestamp': '2026-09-01T12:00:00Z',
        },
        {
          'result': 'win',
          'player_uids': ['u1'],
          'timestamp': '2026-08-31T12:00:00Z',
        },
      ];
      expect(
        streakFromGameHistory(history, memberId: 'u1', displayName: 'Sam'),
        1,
      );
    });

    test('does not credit a member when player_uids is empty', () {
      final history = [
        {
          'result': 'win',
          'player_uids': <String>[],
          'created_at': '2026-09-01T12:00:00Z',
        },
      ];
      expect(
        streakFromGameHistory(history, memberId: 'u1', displayName: 'Sam'),
        isNull,
      );
      final rows = buildMemberStreaks(
        memberUids: ['u1', 'u2'],
        displayNames: const {'u1': 'Sam', 'u2': 'Kit'},
        currentStreaks: const {},
        gameHistory: history,
      );
      expect(rows.every((r) => r.streak == 0), isTrue);
    });

    test('parses postgres-array player_uids from match_history', () {
      expect(
        streakFromGameHistory(
          [
            {
              'result': 'win',
              'player_uids': '{u1}',
              'created_at': '2026-09-01T12:00:00Z',
            },
          ],
          memberId: 'u1',
        ),
        1,
      );
    });
  });

  group('winLossFromGameHistory', () {
    test('counts result win/loss/draw', () {
      final summary = winLossFromGameHistory([
        {'result': 'win'},
        {'result': 'won'},
        {'result': 'loss'},
        {'result': 'draw'},
      ]);
      expect(summary.wins, 2);
      expect(summary.losses, 1);
      expect(summary.draws, 1);
      expect(summary.total, 4);
      expect(summary.winRate, closeTo(2 / 3, 0.001));
    });

    test('counts numeric wins/losses fields', () {
      final summary = winLossFromGameHistory([
        {'wins': 10, 'losses': 4, 'draws': 1},
      ]);
      expect(summary.wins, 10);
      expect(summary.losses, 4);
      expect(summary.draws, 1);
    });

    test('reads won boolean', () {
      final summary = winLossFromGameHistory([
        {'won': true},
        {'won': false},
        {'isWin': true},
      ]);
      expect(summary.wins, 2);
      expect(summary.losses, 1);
    });

    test('empty history is empty', () {
      expect(winLossFromGameHistory(const []).isEmpty, isTrue);
    });
  });

  group('winLossFromLobbyStats', () {
    test('parses bigint strings and ignores percent win_rate', () {
      final summary = winLossFromLobbyStats({
        'total_matches': '5',
        'wins': '3',
        'losses': 1,
        'draws': 1.0,
        'win_rate': '60.00',
      });
      expect(summary.wins, 3);
      expect(summary.losses, 1);
      expect(summary.draws, 1);
      expect(summary.winRate, closeTo(0.75, 0.001));
    });

    test('empty or null stats are empty', () {
      expect(winLossFromLobbyStats(null).isEmpty, isTrue);
      expect(winLossFromLobbyStats(const {}).isEmpty, isTrue);
    });

    test('unwraps nested get_lobby_stats / data wrappers', () {
      final summary = winLossFromLobbyStats({
        'get_lobby_stats': {
          'wins': 4,
          'losses': 2,
          'draws': 0,
        },
      });
      expect(summary.wins, 4);
      expect(summary.losses, 2);
    });
  });

  group('coerceLobbyStatsResponse', () {
    test('reads a list of RPC rows', () {
      final map = coerceLobbyStatsResponse([
        {'wins': 3, 'losses': 1, 'draws': 0, 'total_matches': 4},
      ]);
      expect(map['wins'], 3);
      expect(map['losses'], 1);
    });

    test('parses a Postgres record literal', () {
      final map = coerceLobbyStatsResponse('(5,3,1,1,60.00)');
      expect(map['total_matches'], '5');
      expect(map['wins'], '3');
      expect(map['losses'], '1');
      expect(map['draws'], '1');
      expect(winLossFromLobbyStats(map).wins, 3);
    });

    test('parses JSON text', () {
      final map = coerceLobbyStatsResponse(
        '{"wins":2,"losses":1,"draws":0,"total_matches":3}',
      );
      expect(winLossFromLobbyStats(map).wins, 2);
    });

    test('does not treat an unrelated map as zeroed stats', () {
      expect(coerceLobbyStatsResponse({'foo': 1}), isEmpty);
    });
  });

  group('ratingSummaryFrom', () {
    test('averages nested daily and all-time maps', () {
      final summary = ratingSummaryFrom(
        {
          'Warzone': {'a': 4, 'b': 5},
        },
        {
          'Warzone': {'a': 3, 'b': 5},
          'BF6': {'a': 4},
        },
      );
      expect(summary.dailyAverage, closeTo(4.5, 0.001));
      expect(summary.dailySampleSize, 2);
      expect(summary.allTimeAverage, closeTo(4.0, 0.001));
      expect(summary.allTimeSampleSize, 3);
      expect(RatingSummary.format(summary.dailyAverage), '4.5★');
    });

    test('empty maps format as em dash', () {
      const empty = RatingSummary();
      expect(empty.isEmpty, isTrue);
      expect(RatingSummary.format(null), '—');
    });
  });

  group('StatsDashboardSnapshot.fromSources', () {
    test('wires user streaks, lobby history, and ratings', () {
      final user = _user(
        currentStreaks: const {'u1': 3, 'me': 1},
        dailyRatings: const {
          'Warzone': {'me': 5},
        },
        allTimeRatings: const {
          'Warzone': {'me': 4, 'u1': 2},
        },
      );
      final lobby = LobbyState.initial().copyWith(
        lobbyMemberUids: ['me', 'u1'],
        memberDisplayNames: const {'me': 'Alex', 'u1': 'Sam'},
        gameHistory: [
          {'result': 'win'},
          {'result': 'loss'},
          {'result': 'win'},
        ],
      );
      final snap = StatsDashboardSnapshot.fromSources(user: user, lobby: lobby);
      expect(snap.memberStreaks.length, 2);
      expect(snap.winLoss.wins, 2);
      expect(snap.winLoss.losses, 1);
      expect(snap.ratings.dailyAverage, 5);
      expect(snap.ratings.allTimeAverage, 3);
      expect(snap.hasStreaks, isTrue);
    });

    test('falls back to lobby ratings when user maps are empty', () {
      final snap = StatsDashboardSnapshot.fromSources(
        user: _user(),
        lobby: LobbyState.initial().copyWith(
          allTimeRatings: const {
            'Warzone': {'me': 4},
          },
        ),
      );
      expect(snap.ratings.allTimeAverage, 4);
    });

    test('prefers session ratings encoded in match_history notes', () {
      final now = DateTime.utc(2026, 9, 3, 18);
      final today = encodeSessionRatingNotes(
        reduceSessionRating(
          current: SessionRatingState.unrated,
          event: SessionRatingEvent.rate,
          stars: 5,
          ratedAt: DateTime.utc(2026, 9, 3, 12),
        ),
      );
      final older = encodeSessionRatingNotes(
        reduceSessionRating(
          current: SessionRatingState.unrated,
          event: SessionRatingEvent.rate,
          stars: 3,
          ratedAt: DateTime.utc(2026, 9, 1),
        ),
      );
      final snap = StatsDashboardSnapshot.fromSources(
        user: _user(
          dailyRatings: const {
            'Warzone': {'me': 1},
          },
          allTimeRatings: const {
            'Warzone': {'me': 1},
          },
        ),
        extraHistory: [
          {'result': 'win', 'notes': today},
          {'result': 'loss', 'notes': older},
        ],
        now: now,
      );
      expect(snap.ratings.dailyAverage, 5);
      expect(snap.ratings.dailySampleSize, 1);
      expect(snap.ratings.allTimeAverage, 4);
      expect(snap.ratings.allTimeSampleSize, 2);
    });
  });

  group('communitySummaryFrom', () {
    test('counts complaints, bans, friends, and per-game averages', () {
      final summary = communitySummaryFrom(
        _user(
          allTimeRatings: const {
            'Warzone': {'a': 4, 'b': 5},
            'BF6': {'a': 3},
          },
        ).copyWith(
          complaints: const {
            'Warzone': {'u2': 1},
          },
          bans: const {
            'Warzone': [
              {'reason': 'toxicity'},
            ],
          },
          friends: const ['f1', 'f2', 'f3'],
        ),
      );
      expect(summary.complaints, 1);
      expect(summary.bans, 1);
      expect(summary.friends, 3);
      expect(summary.gameAverages.map((g) => g.gameName).toList(),
          ['BF6', 'Warzone']);
      expect(
        summary.gameAverages.firstWhere((g) => g.gameName == 'Warzone').average,
        closeTo(4.5, 0.001),
      );
    });
  });

  group('lobbyIdsForStats', () {
    test('prefers selectedLobbyId over current and userLobbies', () {
      final lobby = LobbyState.initial().copyWith(
        selectedLobbyId: 'sel',
        currentLobby: _lobby(id: 'cur', members: ['a']),
        userLobbies: {
          'sel': _lobby(id: 'sel', members: ['a']),
          'a': _lobby(id: 'a', members: ['a']),
          'b': _lobby(id: 'b', members: ['b']),
        },
      );
      expect(lobbyIdsForStats(lobby), ['sel']);
    });

    test('prefers current lobby over userLobbies', () {
      final lobby = LobbyState.initial().copyWith(
        currentLobby: _lobby(id: 'cur', members: ['a']),
        userLobbies: {
          'a': _lobby(id: 'a', members: ['a']),
          'b': _lobby(id: 'b', members: ['b']),
        },
      );
      expect(lobbyIdsForStats(lobby), ['cur']);
    });

    test('unions userLobbies when nothing is selected', () {
      final lobby = LobbyState.initial().copyWith(
        userLobbies: {
          'a': _lobby(id: 'a', members: ['a']),
          'b': _lobby(id: 'b', members: ['b']),
        },
      );
      expect(lobbyIdsForStats(lobby).toSet(), {'a', 'b'});
    });

    test('resolves selectedLobbyId when it is the lobby chatGroupId', () {
      final lobby = LobbyState.initial().copyWith(
        selectedLobbyId: 'chat-99',
        userLobbies: {
          'lobby-1': _lobby(id: 'lobby-1', members: ['u1'])
              .copyWith(chatGroupId: 'chat-99'),
        },
      );
      expect(resolveStatsLobbyId(lobby, 'chat-99'), 'lobby-1');
      expect(lobbyIdsForStats(lobby), ['lobby-1']);
    });

    test('does not query an unknown selected id when userLobbies exist', () {
      final lobby = LobbyState.initial().copyWith(
        selectedLobbyId: 'chat-thread',
        userLobbies: {
          'lobby-1': _lobby(id: 'lobby-1', members: ['u1']),
        },
      );
      expect(resolveStatsLobbyId(lobby, 'chat-thread'), isNull);
      expect(lobbyIdsForStats(lobby), ['lobby-1']);
    });
  });

  group('loadStatsDashboardSnapshot', () {
    test('uses getLobbyStats W/L and match_history streaks, not empty gameHistory',
        () async {
      final fetchedIds = <String>[];
      final snap = await loadStatsDashboardSnapshot(
        user: _user(uid: 'u1', displayName: 'Sam'),
        lobby: LobbyState.initial().copyWith(
          selectedLobbyId: 'lobby-1',
          lobbyMemberUids: ['u1', 'u2'],
          memberDisplayNames: const {'u1': 'Sam', 'u2': 'Kit'},
          gameHistory: const [],
        ),
        fetchLobbyStats: (id) async {
          fetchedIds.add('stats:$id');
          return {
            'total_matches': 4,
            'wins': 3,
            'losses': 1,
            'draws': 0,
            'win_rate': 75.0,
          };
        },
        fetchMatchHistory: (id) async {
          fetchedIds.add('history:$id');
          return [
            {
              'id': 'm1',
              'lobby_id': id,
              'game_name': 'Warzone',
              'result': 'win',
              'player_uids': ['u1'],
              'created_at': '2026-09-01T12:00:00Z',
              'created_by': 'u1',
            },
            {
              'id': 'm2',
              'lobby_id': id,
              'game_name': 'Warzone',
              'result': 'win',
              'player_uids': ['u1'],
              'created_at': '2026-08-31T12:00:00Z',
              'created_by': 'u1',
            },
            {
              'id': 'm3',
              'lobby_id': id,
              'game_name': 'Warzone',
              'result': 'loss',
              'player_uids': ['u1'],
              'created_at': '2026-08-30T12:00:00Z',
              'created_by': 'u1',
            },
            {
              'id': 'm4',
              'lobby_id': id,
              'game_name': 'Warzone',
              'result': 'win',
              'player_uids': <String>[],
              'created_at': '2026-09-02T12:00:00Z',
              'created_by': 'u1',
            },
          ];
        },
      );

      expect(fetchedIds, ['stats:lobby-1', 'history:lobby-1']);
      expect(snap.winLoss.wins, 3);
      expect(snap.winLoss.losses, 1);
      expect(snap.winLoss.draws, 0);
      expect(snap.winLossTitle, 'Squad wins / losses');
      final byId = {for (final row in snap.memberStreaks) row.id: row.streak};
      expect(byId['u1'], 2);
      expect(byId['u2'], 0);
    });

    test('queries the lobby UUID when selectedLobbyId is the chat group id',
        () async {
      final fetchedIds = <String>[];
      final snap = await loadStatsDashboardSnapshot(
        user: _user(uid: 'u1', displayName: 'Sam'),
        lobby: LobbyState.initial().copyWith(
          selectedLobbyId: 'chat-99',
          lobbyMemberUids: ['u1'],
          memberDisplayNames: const {'u1': 'Sam'},
          userLobbies: {
            'lobby-1': _lobby(id: 'lobby-1', members: ['u1'])
                .copyWith(chatGroupId: 'chat-99'),
          },
        ),
        fetchLobbyStats: (id) async {
          fetchedIds.add('stats:$id');
          return {'wins': 5, 'losses': 2, 'draws': 0, 'total_matches': 7};
        },
        fetchMatchHistory: (id) async {
          fetchedIds.add('history:$id');
          return [
            {
              'result': 'win',
              'playerUids': ['u1'],
              'createdAt': '2026-09-01T12:00:00Z',
            },
          ];
        },
      );

      expect(fetchedIds, ['stats:lobby-1', 'history:lobby-1']);
      expect(snap.statsLobbyIds, ['lobby-1']);
      expect(snap.winLoss.wins, 5);
      expect(snap.winLoss.losses, 2);
      expect(snap.winLoss.isEmpty, isFalse);
      expect(snap.memberStreaks.single.streak, 1);
    });

    test('counts camelCase match_history rows when get_lobby_stats is zero',
        () async {
      final snap = await loadStatsDashboardSnapshot(
        user: _user(uid: 'u1'),
        lobby: LobbyState.initial().copyWith(
          selectedLobbyId: 'lobby-1',
          lobbyMemberUids: ['u1'],
        ),
        fetchLobbyStats: (_) async => {
          'total_matches': 0,
          'wins': 0,
          'losses': 0,
          'draws': 0,
        },
        fetchMatchHistory: (_) async => [
          {
            'outcome': 'win',
            'playerUids': ['u1'],
            'createdAt': '2026-09-01T12:00:00Z',
          },
          {
            'outcome': 'loss',
            'playerUids': ['u1'],
            'createdAt': '2026-08-31T12:00:00Z',
          },
        ],
      );
      expect(snap.winLoss.wins, 1);
      expect(snap.winLoss.losses, 1);
    });

    test('rethrows when every lobby fetch fails', () async {
      await expectLater(
        loadStatsDashboardSnapshot(
          user: _user(),
          lobby: LobbyState.initial().copyWith(selectedLobbyId: 'lobby-1'),
          fetchLobbyStats: (_) async => throw Exception('stats down'),
          fetchMatchHistory: (_) async => throw Exception('history down'),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('keeps partial W/L when one of two lobby fetches fails', () async {
      final snap = await loadStatsDashboardSnapshot(
        user: _user(),
        lobby: LobbyState.initial().copyWith(
          userLobbies: {
            'a': _lobby(id: 'a', members: ['u1']),
            'b': _lobby(id: 'b', members: ['u1']),
          },
        ),
        fetchLobbyStats: (id) async {
          if (id == 'a') throw Exception('stats down');
          return {'wins': 2, 'losses': 1, 'draws': 0};
        },
        fetchMatchHistory: (_) async => const [],
      );
      expect(snap.winLoss.wins, 2);
      expect(snap.winLoss.losses, 1);
      expect(snap.winLossTitle, 'All lobbies wins / losses');
    });

    test('titles aggregated W/L as All lobbies when no lobby is selected',
        () async {
      final snap = await loadStatsDashboardSnapshot(
        user: _user(),
        lobby: LobbyState.initial().copyWith(
          userLobbies: {
            'a': _lobby(id: 'a', members: ['u1']),
            'b': _lobby(id: 'b', members: ['u1']),
          },
        ),
        fetchLobbyStats: (_) async => {'wins': 1, 'losses': 0, 'draws': 0},
        fetchMatchHistory: (_) async => const [],
      );
      expect(snap.statsLobbyIds.toSet(), {'a', 'b'});
      expect(snap.isAggregatedAcrossLobbies, isTrue);
      expect(snap.winLossTitle, 'All lobbies wins / losses');
      expect(snap.winLoss.wins, 2);
    });
  });

  group('SquadMemberStreak.shortLabel', () {
    test('truncates long names', () {
      const row = SquadMemberStreak(
        id: 'x',
        label: 'LongNameHere',
        streak: 1,
      );
      expect(row.shortLabel, 'LongNam…');
      expect(
        const SquadMemberStreak(id: 'x', label: 'Sam', streak: 1).shortLabel,
        'Sam',
      );
    });
  });
}
