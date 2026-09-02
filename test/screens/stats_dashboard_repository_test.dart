import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/domain/entities/app_user.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/presentation/notifiers/user_notifier.dart';
import 'package:squad_sync/screens/performance_stats_screen.dart';

import '../mocks/mock_repositories.mocks.dart';

AppUser _user() {
  return AppUser(
    uid: 'u1',
    displayName: 'Sam',
    profileImage: null,
    preferredModes: const {},
    userBlocks: const {},
    pinnedGames: const [],
    notificationSettings: const {},
    hasRatedGame: const {},
    dailyRatings: const {},
    allTimeRatings: const {
      'Warzone': {'u1': 4, 'u2': 5},
    },
    currentStreaks: const {},
    complaints: const {
      'Warzone': {'u2': 1},
    },
    bans: const {},
    dailyBanVotes: const {},
    blockedUsers: const [],
    friends: const ['f1', 'f2'],
    alerts: const [],
    userGroups: const [],
    alertCircles: const [],
    publicGroups: const [],
    pinnedMessages: const [],
  );
}

class _SeededUserNotifier extends UserNotifier {
  _SeededUserNotifier(this._user);

  final AppUser _user;

  @override
  Future<AppUser?> build() async => _user;
}

class _SeededLobbyNotifier extends LobbyNotifier {
  _SeededLobbyNotifier(this._lobby);

  final LobbyState _lobby;

  @override
  Future<LobbyState> build() async => _lobby;
}

void main() {
  testWidgets(
    'Stats screen reads W/L and streaks from repository, not empty gameHistory',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockLobbyRepository();
      when(repo.getLobbyStats('lobby-1')).thenAnswer(
        (_) async => {
          'total_matches': 4,
          'wins': 3,
          'losses': 1,
          'draws': 0,
          'win_rate': 75.0,
        },
      );
      when(repo.getMatchHistory('lobby-1')).thenAnswer(
        (_) async => [
          {
            'id': 'm1',
            'lobby_id': 'lobby-1',
            'game_name': 'Warzone',
            'result': 'win',
            'player_uids': ['u1'],
            'created_at': '2026-09-01T12:00:00Z',
            'created_by': 'u1',
          },
          {
            'id': 'm2',
            'lobby_id': 'lobby-1',
            'game_name': 'Warzone',
            'result': 'win',
            'player_uids': ['u1'],
            'created_at': '2026-08-31T12:00:00Z',
            'created_by': 'u1',
          },
          {
            'id': 'm3',
            'lobby_id': 'lobby-1',
            'game_name': 'Warzone',
            'result': 'loss',
            'player_uids': ['u1'],
            'created_at': '2026-08-30T12:00:00Z',
            'created_by': 'u1',
          },
        ],
      );

      final user = _user();
      final lobby = LobbyState.initial().copyWith(
        selectedLobbyId: 'lobby-1',
        lobbyMemberUids: ['u1', 'u2'],
        memberDisplayNames: const {'u1': 'Sam', 'u2': 'Kit'},
        gameHistory: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lobbyRepositoryProvider.overrideWithValue(repo),
            userNotifierProvider.overrideWith(() => _SeededUserNotifier(user)),
            lobbyNotifierProvider.overrideWith(() => _SeededLobbyNotifier(lobby)),
          ],
          child: const MaterialApp(
            home: PerformanceStatsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Wins 3'), findsOneWidget);
      expect(find.text('Losses 1'), findsOneWidget);
      expect(find.text('75% win rate'), findsOneWidget);
      expect(find.text('SQUAD WINS / LOSSES'), findsOneWidget);
      expect(find.text('Sam'), findsWidgets);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('2'), findsWidgets);

      verify(repo.getLobbyStats('lobby-1')).called(1);
      verify(repo.getMatchHistory('lobby-1')).called(1);
    },
  );
}
