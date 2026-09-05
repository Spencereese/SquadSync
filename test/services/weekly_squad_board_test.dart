import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:squad_sync/services/weekly_squad_board.dart';

void main() {
  final now = DateTime.utc(2026, 9, 5, 18);

  Map<String, dynamic> row({
    required DateTime at,
    String? result = 'win',
    String? game = 'Warzone',
    List<String>? players,
    int? stars,
    int? comms,
    int? vibes,
    bool locked = false,
    String? id,
  }) {
    String? notes;
    if (stars == null && comms == null && vibes == null && locked) {
      notes = '{"locked":true}';
    } else if (stars != null || comms != null || vibes != null || locked) {
      notes = jsonEncode({
        kSessionRatingNotesKey: {
          'v': 1,
          if (stars != null) 'stars': stars,
          'rated_at': at.toUtc().toIso8601String(),
          if (comms != null) 'comms': comms,
          if (vibes != null) 'vibes': vibes,
          if (locked) 'locked': true,
        },
      });
    }
    return {
      if (id != null) 'id': id,
      'game_name': game,
      'result': result,
      'created_at': at.toIso8601String(),
      if (players != null) 'player_uids': players,
      if (notes != null) 'notes': notes,
    };
  }

  group('weeklySquadBoardFromHistory', () {
    test('empty history is an empty board', () {
      expect(weeklySquadBoardFromHistory(const [], now: now).isEmpty, isTrue);
      expect(
        weeklySquadBoardFromHistory(const [], now: now).nightsPlayed,
        0,
      );
    });

    test('counts unique UTC nights inside the 7-day window', () {
      final board = weeklySquadBoardFromHistory(
        [
          row(at: DateTime.utc(2026, 9, 5, 2), stars: 4),
          row(at: DateTime.utc(2026, 9, 5, 22), stars: 5),
          row(at: DateTime.utc(2026, 9, 3, 20), stars: 3),
          row(at: DateTime.utc(2026, 8, 20), stars: 5),
        ],
        now: now,
      );
      expect(board.nightsPlayed, 2);
      expect(board.isEmpty, isFalse);
    });

    test('lock-in is rated nights over nights played', () {
      final board = weeklySquadBoardFromHistory(
        [
          row(at: DateTime.utc(2026, 9, 5), stars: 4),
          row(at: DateTime.utc(2026, 9, 4), result: 'loss'),
          row(at: DateTime.utc(2026, 9, 3), stars: 5),
        ],
        now: now,
      );
      expect(board.nightsPlayed, 3);
      expect(board.lockInRate, closeTo(2 / 3, 0.001));
      expect(weeklySquadBoardLockInLabel(board.lockInRate), '67%');
    });

    test('notes locked flag counts as lock-in without stars', () {
      final board = weeklySquadBoardFromHistory(
        [
          row(at: DateTime.utc(2026, 9, 5), locked: true),
          row(at: DateTime.utc(2026, 9, 4)),
        ],
        now: now,
      );
      expect(board.nightsPlayed, 2);
      expect(board.lockInRate, 0.5);
    });

    test('comms and vibes average from session_rating notes', () {
      final board = weeklySquadBoardFromHistory(
        [
          row(
            at: DateTime.utc(2026, 9, 5),
            stars: 4,
            comms: 5,
            vibes: 3,
          ),
          row(
            at: DateTime.utc(2026, 9, 4),
            stars: 2,
            comms: 3,
            vibes: 5,
          ),
        ],
        now: now,
      );
      expect(board.commsAverage, 4);
      expect(board.vibesAverage, 4);
      expect(board.commsSampleSize, 2);
      expect(board.vibesSampleSize, 2);
    });

    test('falls back to player Comms/Vibes maps then session stars', () {
      final fromMaps = weeklySquadBoardFromHistory(
        [
          row(at: DateTime.utc(2026, 9, 5), stars: 2, players: ['u1']),
        ],
        now: now,
        memberUids: const ['u1'],
        categoryRatings: const {
          'u1': {'Comms': 5, 'Vibes': 4},
        },
      );
      expect(fromMaps.commsAverage, 5);
      expect(fromMaps.vibesAverage, 4);

      final fromStars = weeklySquadBoardFromHistory(
        [
          row(at: DateTime.utc(2026, 9, 5), stars: 5),
          row(at: DateTime.utc(2026, 9, 4), stars: 3),
        ],
        now: now,
      );
      expect(fromStars.commsAverage, isNull);
      expect(fromStars.vibesAverage, 4);
    });

    test('ranks members by nights then lock-in from player_uids', () {
      final board = weeklySquadBoardFromHistory(
        [
          row(
            at: DateTime.utc(2026, 9, 5),
            stars: 5,
            comms: 4,
            vibes: 5,
            players: ['u1', 'u2'],
          ),
          row(
            at: DateTime.utc(2026, 9, 4),
            stars: 4,
            players: ['u1'],
          ),
          row(
            at: DateTime.utc(2026, 9, 3),
            result: 'loss',
            players: ['u2'],
          ),
        ],
        now: now,
        memberUids: const ['u1', 'u2'],
        displayNames: const {'u1': 'Sam', 'u2': 'Kit'},
      );
      expect(board.rows, hasLength(2));
      expect(board.rows.first.label, 'Sam');
      expect(board.rows.first.nightsPlayed, 2);
      expect(board.rows.first.lockInRate, 1);
      expect(board.rows.last.label, 'Kit');
      expect(board.rows.last.nightsPlayed, 2);
      expect(board.rows.last.lockInRate, 0.5);
      expect(
        weeklySquadBoardRowLabel(board.rows.first),
        'Sam · 2n · 100% · C4.0 · V5.0',
      );
    });

    test('missing player_uids does not credit every member', () {
      final board = weeklySquadBoardFromHistory(
        [
          row(at: DateTime.utc(2026, 9, 5), stars: 4),
        ],
        now: now,
        memberUids: const ['u1', 'u2'],
        displayNames: const {'u1': 'Sam', 'u2': 'Kit'},
      );
      expect(board.nightsPlayed, 1);
      expect(board.rows, isEmpty);
    });
  });
}
