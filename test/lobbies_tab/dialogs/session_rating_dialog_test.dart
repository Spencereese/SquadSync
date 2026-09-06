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
}
