import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/session_rating_machine.dart';

void main() {
  group('reduceSessionRating', () {
    test('unrated → rated on valid stars', () {
      final ratedAt = DateTime.utc(2026, 9, 3, 18);
      final next = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 4,
        lobbyId: 'lobby-1',
        raterUid: 'u1',
        gameName: 'Warzone',
        result: 'win',
        ratedAt: ratedAt,
      );
      expect(next.phase, SessionRatingPhase.rated);
      expect(next.stars, 4);
      expect(next.lobbyId, 'lobby-1');
      expect(next.raterUid, 'u1');
      expect(next.gameName, 'Warzone');
      expect(next.result, 'win');
      expect(next.ratedAt, ratedAt);
      expect(next.isRated, isTrue);
    });

    test('invalid stars are a no-op', () {
      const looking = SessionRatingState(
        phase: SessionRatingPhase.unrated,
        lobbyId: 'lobby-1',
      );
      for (final stars in [0, 6, -1, null]) {
        final next = reduceSessionRating(
          current: looking,
          event: SessionRatingEvent.rate,
          stars: stars,
        );
        expect(next.phase, SessionRatingPhase.unrated, reason: 'stars=$stars');
        expect(next.stars, isNull);
      }
    });

    test('rate overwrites a previous rating', () {
      final first = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 2,
        lobbyId: 'lobby-1',
        ratedAt: DateTime.utc(2026, 9, 1),
      );
      final next = reduceSessionRating(
        current: first,
        event: SessionRatingEvent.rate,
        stars: 5,
        ratedAt: DateTime.utc(2026, 9, 3),
      );
      expect(next.stars, 5);
      expect(next.lobbyId, 'lobby-1');
      expect(next.phase, SessionRatingPhase.rated);
    });

    test('skip from unrated', () {
      final next = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.skip,
        lobbyId: 'lobby-1',
        result: 'loss',
      );
      expect(next.phase, SessionRatingPhase.skipped);
      expect(next.isRated, isFalse);
      expect(next.stars, isNull);
      expect(next.lobbyId, 'lobby-1');
      expect(next.result, 'loss');
    });

    test('skip does not clear an existing rating', () {
      final rated = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 3,
        lobbyId: 'lobby-1',
      );
      final next = reduceSessionRating(
        current: rated,
        event: SessionRatingEvent.skip,
      );
      expect(next.phase, SessionRatingPhase.rated);
      expect(next.stars, 3);
    });

    test('clear returns unrated', () {
      final rated = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 5,
      );
      final next = reduceSessionRating(
        current: rated,
        event: SessionRatingEvent.clear,
      );
      expect(next.phase, SessionRatingPhase.unrated);
      expect(next.stars, isNull);
      expect(next.lobbyId, isNull);
    });
  });

  group('match_history.notes codec', () {
    test('encodes rated snapshot as session_rating JSON', () {
      final rated = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 4,
        lobbyId: 'lobby-1',
        raterUid: 'u1',
        result: 'win',
        ratedAt: DateTime.utc(2026, 9, 3, 18),
      );
      final notes = notesForSessionRating(rated);
      expect(notes, isNotNull);
      final decoded = jsonDecode(notes!) as Map<String, dynamic>;
      expect(decoded[kSessionRatingNotesKey], isA<Map>());
      final inner = Map<String, dynamic>.from(
        decoded[kSessionRatingNotesKey] as Map,
      );
      expect(inner['v'], 1);
      expect(inner['stars'], 4);
      expect(inner['rater_uid'], 'u1');
      expect(inner['lobby_id'], 'lobby-1');
      expect(inner['result'], 'win');
      expect(inner['rated_at'], '2026-09-03T18:00:00.000Z');
    });

    test('notesForSessionRating is null when skipped', () {
      final skipped = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.skip,
      );
      expect(notesForSessionRating(skipped), isNull);
      expect(notesForSessionRating(SessionRatingState.unrated), isNull);
    });

    test('preserves prior plain-text notes under text', () {
      final rated = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 5,
        ratedAt: DateTime.utc(2026, 9, 3),
      );
      final notes = encodeSessionRatingNotes(
        rated,
        existingNotes: 'clutch 1v3',
      );
      final decoded = jsonDecode(notes) as Map<String, dynamic>;
      expect(decoded['text'], 'clutch 1v3');
      expect(decoded[kSessionRatingNotesKey]['stars'], 5);
    });

    test('decodes notes JSON back to a rated snapshot', () {
      const json =
          '{"session_rating":{"v":1,"stars":3,"rater_uid":"u2","rated_at":"2026-09-03T12:00:00.000Z"}}';
      final rating = decodeSessionRatingFromNotes(json, lobbyId: 'lobby-9');
      expect(rating, isNotNull);
      expect(rating!.isRated, isTrue);
      expect(rating.stars, 3);
      expect(rating.raterUid, 'u2');
      expect(rating.lobbyId, 'lobby-9');
      expect(rating.ratedAt, DateTime.utc(2026, 9, 3, 12));
    });

    test('plain text notes are not a rating', () {
      expect(decodeSessionRatingFromNotes('great game'), isNull);
      expect(decodeSessionRatingFromNotes(''), isNull);
      expect(decodeSessionRatingFromNotes(null), isNull);
    });

    test('applySessionRatingToMatchRow stamps notes on a history row', () {
      final rated = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 2,
        raterUid: 'u1',
        ratedAt: DateTime.utc(2026, 9, 3),
      );
      final row = applySessionRatingToMatchRow(
        row: {
          'id': 'm1',
          'lobby_id': 'lobby-1',
          'result': 'loss',
        },
        rating: rated,
      );
      expect(row['id'], 'm1');
      expect(row['result'], 'loss');
      final fromRow = sessionRatingFromMatchRow(row);
      expect(fromRow?.stars, 2);
      expect(fromRow?.raterUid, 'u1');
    });
  });

  group('sessionRatingAveragesFromHistory', () {
    final now = DateTime.utc(2026, 9, 3, 18);

    String notesFor(int stars, DateTime at) {
      return encodeSessionRatingNotes(
        reduceSessionRating(
          current: SessionRatingState.unrated,
          event: SessionRatingEvent.rate,
          stars: stars,
          ratedAt: at,
        ),
      );
    }

    test('splits daily vs all-time by 24h window', () {
      final avg = sessionRatingAveragesFromHistory(
        [
          {
            'notes': notesFor(5, DateTime.utc(2026, 9, 3, 12)),
          },
          {
            'notes': notesFor(3, DateTime.utc(2026, 9, 1, 12)),
          },
          {
            'notes': 'not json',
          },
        ],
        now: now,
      );
      expect(avg.dailySampleSize, 1);
      expect(avg.dailyAverage, 5);
      expect(avg.allTimeSampleSize, 2);
      expect(avg.allTimeAverage, 4);
      expect(avg.isEmpty, isFalse);
    });

    test('empty history is empty averages', () {
      final avg = sessionRatingAveragesFromHistory(const []);
      expect(avg.isEmpty, isTrue);
      expect(avg.dailySampleSize, 0);
      expect(avg.allTimeSampleSize, 0);
    });
  });

  group('sessionRecordedSnackbar', () {
    test('includes stars when rated', () {
      final rated = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 4,
      );
      expect(sessionRecordedSnackbar('win', rated), 'Win recorded · 4★');
      expect(sessionRecordedSnackbar('loss', rated), 'Loss recorded · 4★');
    });

    test('omits stars when skipped', () {
      final skipped = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.skip,
      );
      expect(sessionRecordedSnackbar('win', skipped), 'Win recorded');
    });
  });
}
