import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/squad_analytics.dart';

void main() {
  setUp(SquadAnalytics.resetTestHooks);
  tearDown(SquadAnalytics.resetTestHooks);

  group('event names', () {
    test('are the five Phase C events', () {
      expect(
        kAnalyticsEventNames,
        {
          'lobby_join',
          'peacock_offer',
          'peacock_lock',
          'session_rate',
          'ready_check',
        },
      );
      expect(kAnalyticsLobbyJoin, 'lobby_join');
      expect(kAnalyticsPeacockOffer, 'peacock_offer');
      expect(kAnalyticsPeacockLock, 'peacock_lock');
      expect(kAnalyticsSessionRate, 'session_rate');
      expect(kAnalyticsReadyCheck, 'ready_check');
    });
  });

  group('isAnalyticsPiiKey', () {
    test('strips uid, email, display name, tokens, and ids', () {
      for (final key in [
        'user_id',
        'uid',
        'email',
        'display_name',
        'rater_uid',
        'lobby_id',
        'squad_id',
        'access_token',
        'from_uid',
        'player_uids',
        'comment',
      ]) {
        expect(isAnalyticsPiiKey(key), isTrue, reason: key);
      }
    });

    test('allows coarse product params', () {
      for (final key in [
        'source',
        'game_name',
        'seated_count',
        'ready_count',
        'stars',
        'result',
        'skipped',
        'outcome',
        'seat_index',
      ]) {
        expect(isAnalyticsPiiKey(key), isFalse, reason: key);
      }
    });
  });

  group('sanitizeAnalyticsParams', () {
    test('drops PII and keeps allowed values', () {
      final params = sanitizeAnalyticsParams({
        'source': 'lfg',
        'game_name': 'Warzone',
        'user_id': 'u-secret',
        'email': 'a@b.com',
        'lobby_id': 'lobby-9',
        'display_name': 'Alex',
        'stars': 4,
        'skipped': true,
        'empty': '',
        'bad name': 'x',
      });
      expect(params, {
        'source': 'lfg',
        'game_name': 'Warzone',
        'stars': 4,
        'skipped': 1,
      });
      expect(params.containsKey('user_id'), isFalse);
      expect(params.containsKey('email'), isFalse);
      expect(params.containsKey('lobby_id'), isFalse);
      expect(params.containsKey('display_name'), isFalse);
    });

    test('drops string values that look like emails', () {
      final params = sanitizeAnalyticsParams({
        'source': 'not-an-email@host',
      });
      expect(params, isEmpty);
    });
  });

  group('param builders', () {
    test('lobby_join has source and game only', () {
      expect(
        lobbyJoinParams(source: 'code', gameName: 'Warzone'),
        {'source': 'code', 'game_name': 'Warzone'},
      );
    });

    test('peacock_offer has source, game, seat index', () {
      expect(
        peacockOfferParams(source: 'lfg', gameName: 'MW3', seatIndex: 2),
        {'source': 'lfg', 'game_name': 'MW3', 'seat_index': 2},
      );
    });

    test('peacock_lock is counts only', () {
      expect(
        peacockLockParams(seatedCount: 4, readyCount: 4),
        {'seated_count': 4, 'ready_count': 4},
      );
    });

    test('session_rate has stars, result, skipped — no rater', () {
      expect(
        sessionRateParams(stars: 5, result: 'win', skipped: false),
        {'stars': 5, 'result': 'win', 'skipped': 0},
      );
    });

    test('ready_check has counts and outcome', () {
      expect(
        readyCheckParams(
          seatedCount: 3,
          readyCount: 1,
          outcome: 'ready',
        ),
        {'seated_count': 3, 'ready_count': 1, 'outcome': 'ready'},
      );
    });
  });

  group('SquadAnalytics.log', () {
    test('named helpers fire hook with sanitized params', () async {
      final recorded = <Map<String, Object>>[];
      SquadAnalytics.logHook = (name, params) async {
        recorded.add({'name': name, ...params});
      };

      await SquadAnalytics.logLobbyJoin(source: 'code', gameName: 'Warzone');
      await SquadAnalytics.logPeacockOffer(source: 'peacock_queue');
      await SquadAnalytics.logPeacockLock(seatedCount: 2, readyCount: 2);
      await SquadAnalytics.logSessionRate(stars: 3, result: 'loss');
      await SquadAnalytics.logReadyCheck(outcome: 'timeout');
      await SquadAnalytics.log(kAnalyticsLobbyJoin, {
        'source': 'lfg',
        'user_id': 'should-drop',
        'email': 'x@y.z',
      });

      expect(recorded.map((e) => e['name']), [
        kAnalyticsLobbyJoin,
        kAnalyticsPeacockOffer,
        kAnalyticsPeacockLock,
        kAnalyticsSessionRate,
        kAnalyticsReadyCheck,
        kAnalyticsLobbyJoin,
      ]);
      expect(recorded[0]['source'], 'code');
      expect(recorded[0]['game_name'], 'Warzone');
      expect(recorded[1]['source'], 'peacock_queue');
      expect(recorded[2]['seated_count'], 2);
      expect(recorded[3]['stars'], 3);
      expect(recorded[3]['result'], 'loss');
      expect(recorded[4]['outcome'], 'timeout');
      expect(recorded.last.containsKey('user_id'), isFalse);
      expect(recorded.last.containsKey('email'), isFalse);
      expect(recorded.last['source'], 'lfg');
    });

    test('missing Firebase does not throw', () async {
      SquadAnalytics.resetTestHooks();
      await SquadAnalytics.logLobbyJoin(source: 'code');
    });
  });
}
