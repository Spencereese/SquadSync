import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/data/repositories/matchmaking_queue_repository.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';

void main() {
  group('matchmakingQueueRow / entryFromRow', () {
    test('round-trips looking without created_at overwrite key', () {
      const entry = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.looking,
        squadId: 'squad-1',
        gameName: 'Warzone',
      );
      final row = matchmakingQueueRow('u1', entry);
      expect(row['user_uid'], 'u1');
      expect(row['phase'], 'looking');
      expect(row['squad_id'], 'squad-1');
      expect(row['game_name'], 'Warzone');
      expect(row.containsKey('created_at'), isFalse);
      expect(row.containsKey('id'), isFalse);

      final parsed = matchmakingQueueEntryFromRow({
        ...row,
        'created_at': '2026-09-03T12:00:00.000Z',
      });
      expect(parsed?.phase, MatchmakingQueuePhase.looking);
      expect(parsed?.squadId, 'squad-1');
      expect(parsed?.gameName, 'Warzone');
      expect(parsed?.queuedAt, DateTime.parse('2026-09-03T12:00:00.000Z').toUtc());
    });

    test('idle / unknown phase rows are dropped', () {
      expect(
        matchmakingQueueEntryFromRow({'user_uid': 'u1', 'phase': 'idle'}),
        isNull,
      );
      expect(
        matchmakingQueueEntryFromRow({'user_uid': 'u1', 'phase': 'nope'}),
        isNull,
      );
      expect(matchmakingQueueEntryFromRow(null), isNull);
    });

    test('delete payload becomes an idle change', () {
      final change = matchmakingQueueChangeFromPayload(
        eventType: 'DELETE',
        oldRecord: {'user_uid': 'u1', 'phase': 'looking'},
      );
      expect(change?.userId, 'u1');
      expect(change?.entry, isNull);
    });

    test('insert payload maps matched lobby', () {
      final change = matchmakingQueueChangeFromPayload(
        eventType: 'INSERT',
        newRecord: {
          'user_uid': 'u1',
          'phase': 'matched',
          'lobby_id': 'lobby-9',
          'game_name': 'Warzone',
        },
      );
      expect(change?.userId, 'u1');
      expect(change?.entry?.phase, MatchmakingQueuePhase.matched);
      expect(change?.entry?.lobbyId, 'lobby-9');
      expect(change?.entry?.hasJoinTarget, isTrue);
    });
  });

  group('null-client repository', () {
    test('fetchActive and upsert no-op without a client', () async {
      final repo = MatchmakingQueueRepositoryImpl(client: null);
      await repo.upsert(
        'u1',
        const MatchmakingQueueEntry(phase: MatchmakingQueuePhase.looking),
      );
      expect(await repo.fetchActive(), isEmpty);
      await repo.remove('u1');
      expect(repo.watch(), isA<Stream<MatchmakingQueueChange>>());
      await repo.dispose();
    });
  });
}
