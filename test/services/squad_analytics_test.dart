import 'package:flutter/foundation.dart';
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

    test('lfg enqueue reuses lobby_join source and game only', () {
      expect(
        lfgEnqueueParams(gameName: 'Warzone'),
        {'source': 'lfg', 'game_name': 'Warzone'},
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
      await SquadAnalytics.logLfgEnqueue(gameName: 'MW3');
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
        kAnalyticsLobbyJoin,
      ]);
      expect(recorded[0]['source'], 'code');
      expect(recorded[0]['game_name'], 'Warzone');
      expect(recorded[1]['source'], 'peacock_queue');
      expect(recorded[2]['seated_count'], 2);
      expect(recorded[3]['stars'], 3);
      expect(recorded[3]['result'], 'loss');
      expect(recorded[4]['outcome'], 'timeout');
      expect(recorded[5]['source'], 'lfg');
      expect(recorded[5]['game_name'], 'MW3');
      expect(recorded.last.containsKey('user_id'), isFalse);
      expect(recorded.last.containsKey('email'), isFalse);
      expect(recorded.last['source'], 'lfg');
      expect(SquadAnalytics.lastResult?.isSuccess, isTrue);
    });

    test('missing Firebase does not throw', () async {
      SquadAnalytics.resetTestHooks();
      final result = await SquadAnalytics.logLobbyJoin(source: 'code');
      expect(result.isSuccess, isFalse);
      expect(result.isFailed || result.isEmpty, isTrue);
    });

    test('captureLogs mocks Firebase and records sanitized events', () async {
      final logged = SquadAnalytics.captureLogs();
      await SquadAnalytics.logLobbyJoin(
        source: 'code',
        gameName: 'Warzone',
      );
      await SquadAnalytics.log(kAnalyticsLobbyJoin, {
        'source': 'lfg',
        'user_id': 'drop-me',
        'lobby_id': 'lobby-9',
      });
      expect(logged.map((e) => e.name), [
        kAnalyticsLobbyJoin,
        kAnalyticsLobbyJoin,
      ]);
      expect(logged.first.params, {
        'source': 'code',
        'game_name': 'Warzone',
      });
      expect(logged.last.params, {'source': 'lfg'});
      expect(logged.last.params.containsKey('user_id'), isFalse);
      expect(logged.last.params.containsKey('lobby_id'), isFalse);
      expect(SquadAnalytics.lastResult?.isSuccess, isTrue);
    });
  });

  group('analytics fire/persist mapper', () {
    test('blank name is empty, not a silent success', () async {
      var calls = 0;
      final result = await runAnalyticsFire(
        (name, params) async {
          calls++;
        },
        name: '   ',
      );
      expect(result.isEmpty, isTrue);
      expect(result.isSuccess, isFalse);
      expect(calls, 0);
      expect(analyticsFireMessage(result), kAnalyticsFireEmptyCopy);
      expect(analyticsFireHint(result), kAnalyticsFireEmptyHint);
      expect(
        analyticsFireFeedbackKey(result.outcome),
        const Key('analytics-fire-empty'),
      );
      expect(
        analyticsFireHintKey(result.outcome),
        const Key('analytics-fire-empty-hint'),
      );
    });

    test('SquadAnalytics.log empty name is empty', () async {
      final result = await SquadAnalytics.log('  ');
      expect(result.isEmpty, isTrue);
      expect(SquadAnalytics.lastResult?.isEmpty, isTrue);
    });

    test('thrown fire is error, not a silent success', () async {
      final result = await runAnalyticsFire(
        (name, params) async => throw Exception('offline'),
        name: kAnalyticsPeacockLock,
        parameters: peacockLockParams(seatedCount: 2, readyCount: 2),
      );
      expect(result.isFailed, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.name, kAnalyticsPeacockLock);
      expect(analyticsFireErrorDetail(result.error), 'offline');
      expect(analyticsFireMessage(result), kAnalyticsFireErrorCopy);
      expect(analyticsFireHint(result), kAnalyticsFireErrorHint);
      expect(
        analyticsFireFeedbackKey(result.outcome),
        const Key('analytics-fire-error'),
      );
      expect(analyticsFireRetryKey(), const Key('analytics-fire-retry'));
      expect(
        analyticsFireDetailKey(),
        const Key('analytics-fire-error-detail'),
      );
    });

    test('retry re-runs fire and can succeed', () async {
      var calls = 0;
      Future<void> fire(String name, Map<String, Object> params) async {
        calls++;
        if (calls == 1) throw Exception('offline');
      }

      final first = await runAnalyticsFire(
        fire,
        name: kAnalyticsSessionRate,
        parameters: sessionRateParams(stars: 4, result: 'win'),
      );
      expect(first.isFailed, isTrue);
      expect(calls, 1);

      final second = await retryAnalyticsFire(
        fire,
        name: kAnalyticsSessionRate,
        parameters: sessionRateParams(stars: 4, result: 'win'),
      );
      expect(second.isSuccess, isTrue);
      expect(calls, 2);
      expect(second.params['stars'], 4);
    });

    test('retry after error can stay error', () async {
      Future<void> fire(String name, Map<String, Object> params) async {
        throw Exception('denied');
      }

      final first = await runAnalyticsFire(
        fire,
        name: kAnalyticsLobbyJoin,
      );
      final second = await retryAnalyticsFire(
        fire,
        name: kAnalyticsLobbyJoin,
      );
      expect(first.isFailed, isTrue);
      expect(second.isFailed, isTrue);
      expect(analyticsFireErrorDetail(second.error), 'denied');
    });
  });

  group('key events success + fail', () {
    test('lock-in success fires peacock_lock without PII', () async {
      final logged = SquadAnalytics.captureLogs();
      final result = await SquadAnalytics.logPeacockLock(
        seatedCount: 4,
        readyCount: 4,
      );
      expect(result.isSuccess, isTrue);
      expect(logged.single.name, kAnalyticsPeacockLock);
      expect(logged.single.params, {
        'seated_count': 4,
        'ready_count': 4,
      });
      expect(logged.single.params.containsKey('lobby_id'), isFalse);
      expect(logged.single.params.containsKey('user_id'), isFalse);
      expect(
        analyticsFireFeedbackKey(result.outcome),
        const Key('analytics-fire-success'),
      );
    });

    test('lock-in fire fail is error, not success', () async {
      SquadAnalytics.logHook = (_, __) async => throw Exception('offline');
      final result = await SquadAnalytics.logPeacockLock(
        seatedCount: 2,
        readyCount: 2,
      );
      expect(result.isFailed, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.name, kAnalyticsPeacockLock);
      expect(analyticsFireErrorDetail(result.error), 'offline');
      expect(SquadAnalytics.lastResult?.isFailed, isTrue);
    });

    test('peacock join success fires peacock_offer without PII', () async {
      final logged = SquadAnalytics.captureLogs();
      final result = await SquadAnalytics.logPeacockOffer(
        source: 'peacock_queue',
        gameName: 'Warzone',
        seatIndex: 1,
      );
      expect(result.isSuccess, isTrue);
      expect(logged.single.name, kAnalyticsPeacockOffer);
      expect(logged.single.params, {
        'source': 'peacock_queue',
        'game_name': 'Warzone',
        'seat_index': 1,
      });
      expect(logged.single.params.containsKey('user_id'), isFalse);
      expect(logged.single.params.containsKey('lobby_id'), isFalse);
    });

    test('peacock join fire fail is error, not success', () async {
      SquadAnalytics.logHook = (_, __) async => throw Exception('denied');
      final result = await SquadAnalytics.logPeacockOffer(
        source: 'peacock_queue',
        gameName: 'Warzone',
      );
      expect(result.isFailed, isTrue);
      expect(result.name, kAnalyticsPeacockOffer);
      expect(analyticsFireErrorDetail(result.error), 'denied');
    });

    test('rating submit success fires session_rate without rater', () async {
      final logged = SquadAnalytics.captureLogs();
      final result = await SquadAnalytics.logSessionRate(
        stars: 5,
        result: 'win',
      );
      expect(result.isSuccess, isTrue);
      expect(logged.single.name, kAnalyticsSessionRate);
      expect(logged.single.params, {
        'stars': 5,
        'result': 'win',
        'skipped': 0,
      });
      expect(logged.single.params.containsKey('rater_uid'), isFalse);
      expect(logged.single.params.containsKey('comment'), isFalse);
    });

    test('rating submit fire fail is error, not success', () async {
      SquadAnalytics.logHook = (_, __) async => throw Exception('offline');
      final result = await SquadAnalytics.logSessionRate(
        stars: 3,
        result: 'loss',
      );
      expect(result.isFailed, isTrue);
      expect(result.name, kAnalyticsSessionRate);
      expect(analyticsFireErrorDetail(result.error), 'offline');
    });

    test('LFG enqueue success fires lobby_join source lfg', () async {
      final logged = SquadAnalytics.captureLogs();
      final result = await SquadAnalytics.logLfgEnqueue(gameName: 'Warzone');
      expect(result.isSuccess, isTrue);
      expect(logged.single.name, kAnalyticsLobbyJoin);
      expect(logged.single.params, {
        'source': 'lfg',
        'game_name': 'Warzone',
      });
      expect(logged.single.params.containsKey('user_id'), isFalse);
      expect(logged.single.params.containsKey('squad_id'), isFalse);
    });

    test('LFG enqueue fire fail is error, not success', () async {
      SquadAnalytics.logHook = (_, __) async => throw Exception('offline');
      final result = await SquadAnalytics.logLfgEnqueue(gameName: 'Warzone');
      expect(result.isFailed, isTrue);
      expect(result.name, kAnalyticsLobbyJoin);
      expect(analyticsFireErrorDetail(result.error), 'offline');
      expect(analyticsFireMessage(result), kAnalyticsFireErrorCopy);
    });
  });
}
