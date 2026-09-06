import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/lobbies_tab/dialogs/session_rating_dialog.dart';
import 'package:squad_sync/services/session_rating_machine.dart';

void main() {
  testWidgets('submit is disabled until a category is chosen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SessionRatingDialog(lobbyId: 'lobby-1', raterUid: 'u1'),
      ),
    );

    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('session-rating-submit')),
    );
    expect(submit.onPressed, isNull);

    await tester.tap(find.byKey(const Key('session-rating-vibes-4')));
    await tester.pump();

    final enabled = tester.widget<FilledButton>(
      find.byKey(const Key('session-rating-submit')),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('submit pops Vibes/Comms/Gunny/Wingman + optional W/L/notes',
      (tester) async {
    SessionRatingState? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showSessionRatingDialog(
                context,
                lobbyId: 'lobby-1',
                raterUid: 'u1',
                result: 'win',
                gameName: 'Warzone',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-rating-vibes-5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('session-rating-comms-4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('session-rating-gunny-3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('session-rating-wingman-2')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('session-rating-notes')),
      'clutch 1v3',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('session-rating-submit')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.phase, SessionRatingPhase.rated);
    expect(result!.vibes, 5);
    expect(result!.comms, 4);
    expect(result!.gunny, 3);
    expect(result!.wingman, 2);
    expect(result!.stars, 4);
    expect(result!.comment, 'clutch 1v3');
    expect(result!.lobbyId, 'lobby-1');
    expect(result!.raterUid, 'u1');
    expect(result!.result, 'win');
    expect(result!.gameName, 'Warzone');
  });

  testWidgets('skip pops a skipped snapshot', (tester) async {
    SessionRatingState? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showSessionRatingDialog(
                context,
                lobbyId: 'lobby-1',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-rating-skip')));
    await tester.pumpAndSettle();

    expect(result!.phase, SessionRatingPhase.skipped);
    expect(result!.isRated, isFalse);
    expect(result!.lobbyId, 'lobby-1');
  });

  testWidgets('empty state until a category is chosen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SessionRatingDialog(lobbyId: 'lobby-1'),
      ),
    );

    expect(find.byKey(const Key('session-rating-empty')), findsOneWidget);
    expect(find.text(kSessionRatingEmptyCopy), findsOneWidget);
    expect(find.text(kSessionRatingEmptyHint), findsOneWidget);
    expect(find.byKey(const Key('session-rating-empty-hint')), findsOneWidget);
    expect(find.byKey(const Key('session-rating-error')), findsNothing);

    await tester.tap(find.byKey(const Key('session-rating-vibes-4')));
    await tester.pump();

    expect(find.byKey(const Key('session-rating-empty')), findsNothing);
    expect(find.text('How was this squad session?'), findsOneWidget);
  });

  testWidgets('persist fail keeps sheet open; retry submits again',
      (tester) async {
    var calls = 0;
    SessionRatingState? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await showSessionRatingDialog(
                context,
                lobbyId: 'lobby-1',
                persist: (rating) async {
                  calls++;
                  if (calls == 1) {
                    return SessionRatingPersistResult.failed(
                      Exception('offline'),
                      rating: rating,
                    );
                  }
                  return SessionRatingPersistResult.success(rating);
                },
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-rating-vibes-5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('session-rating-submit')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(const Key('session-rating-dialog')), findsOneWidget);
    expect(find.byKey(const Key('session-rating-error')), findsOneWidget);
    expect(find.text(kSessionRatingPersistErrorCopy), findsOneWidget);
    expect(find.text(kSessionRatingPersistErrorHint), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    expect(find.byKey(const Key('session-rating-retry')), findsOneWidget);
    expect(popped, isNull);

    await tester.tap(find.byKey(const Key('session-rating-retry')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(popped?.isRated, isTrue);
    expect(popped?.vibes, 5);
    expect(find.byKey(const Key('session-rating-dialog')), findsNothing);
  });

  testWidgets('persist error dialog retry pops true', (tester) async {
    var retry = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              retry = await showSessionRatingPersistErrorDialog(
                context,
                SessionRatingPersistResult.failed(Exception('offline')),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-rating-persist-error')), findsOneWidget);
    expect(find.text(kSessionRatingPersistErrorCopy), findsOneWidget);
    expect(find.byKey(const Key('session-rating-error-hint')), findsOneWidget);
    expect(find.byKey(const Key('session-rating-error-detail')), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-rating-retry')));
    await tester.pumpAndSettle();
    expect(retry, isTrue);
  });

  testWidgets('persist fail snackbar offers retry, not a success toast',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                presentSessionRatingPersist(
                  context,
                  'win',
                  SessionRatingPersistResult.failed(
                    Exception('offline'),
                    rating: reduceSessionRating(
                      current: SessionRatingState.unrated,
                      event: SessionRatingEvent.rate,
                      stars: 4,
                      lobbyId: 'lobby-1',
                    ),
                  ),
                  onRetry: () {
                    retried = true;
                  },
                );
              },
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();

    expect(find.byKey(const Key('session-rating-persist-error')), findsOneWidget);
    expect(find.text(kSessionRatingPersistErrorCopy), findsOneWidget);
    expect(find.text('Win recorded · 4★'), findsNothing);
    final retry = tester.widget<SnackBarAction>(
      find.byKey(const Key('session-rating-retry')),
    );
    retry.onPressed();
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('persist empty snackbar is skip copy, not rated success',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                presentSessionRatingPersist(
                  context,
                  'win',
                  SessionRatingPersistResult.empty(
                    rating: reduceSessionRating(
                      current: const SessionRatingState(lobbyId: 'lobby-1'),
                      event: SessionRatingEvent.skip,
                      lobbyId: 'lobby-1',
                      result: 'win',
                    ),
                  ),
                );
              },
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();

    expect(find.byKey(const Key('session-rating-persist-empty')), findsOneWidget);
    expect(find.text('Win recorded'), findsOneWidget);
    expect(find.text('Win recorded · 4★'), findsNothing);
    expect(find.byKey(const Key('session-rating-retry')), findsNothing);
  });
}
