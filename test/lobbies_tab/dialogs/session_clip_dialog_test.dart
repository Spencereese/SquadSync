import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/lobbies_tab/dialogs/session_clip_dialog.dart';
import 'package:squad_sync/lobbies_tab/dialogs/session_rating_dialog.dart';
import 'package:squad_sync/services/session_rating_flow.dart';
import 'package:squad_sync/services/session_rating_machine.dart';

void main() {
  testWidgets('attach is disabled until a clip is selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionClipDialog(
          pickClip: () async => const SessionClipPick(name: 'clutch.mp4'),
        ),
      ),
    );

    final attach = tester.widget<FilledButton>(
      find.byKey(const Key('session-clip-attach')),
    );
    expect(attach.onPressed, isNull);

    await tester.tap(find.byKey(const Key('session-clip-select')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-clip-file')), findsOneWidget);
    expect(find.text('clutch.mp4'), findsOneWidget);
    final enabled = tester.widget<FilledButton>(
      find.byKey(const Key('session-clip-attach')),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('attach pops an attached clip via the reducer', (tester) async {
    SessionClip? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showSessionClipDialog(
                context,
                pickClip: () async => const SessionClipPick(
                  name: 'ace.mp4',
                  path: '/tmp/ace.mp4',
                ),
                clipId: 'clip-fixed',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-clip-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-clip-attach')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isAttached, isTrue);
    expect(result!.clipId, 'clip-fixed');
    expect(result!.fileName, 'ace.mp4');
    expect(result!.videoUrl, '/tmp/ace.mp4');
    expect(result!.source, kSessionClipGallerySource);
  });

  testWidgets('skip pops an unattached clip', (tester) async {
    SessionClip? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showSessionClipDialog(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-clip-skip')));
    await tester.pumpAndSettle();

    expect(result!.isAttached, isFalse);
    expect(result!.clipId, isNull);
  });

  testWidgets('after rating, collectSessionClip attaches on the existing path',
      (tester) async {
    SessionRatingState? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              var rating = await showSessionRatingDialog(
                context,
                lobbyId: 'lobby-1',
                raterUid: 'u1',
                result: 'win',
                gameName: 'Warzone',
              );
              if (rating.isRated && context.mounted) {
                final clip = await collectSessionClip(
                  context,
                  pickClip: () async => const SessionClipPick(
                    name: 'clutch.mp4',
                    path: '/tmp/clutch.mp4',
                  ),
                  clipId: 'clip-live',
                );
                rating = attachClipToRatedSession(rating, clip);
              }
              result = rating;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-rating-star-4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('session-rating-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-clip-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-clip-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-clip-attach')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isRated, isTrue);
    expect(result!.stars, 4);
    expect(result!.hasClip, isTrue);
    expect(result!.clip?.clipId, 'clip-live');
    expect(result!.clip?.fileName, 'clutch.mp4');
    final notes = notesForSessionRating(result!);
    expect(decodeSessionClipFromNotes(notes)?.clipId, 'clip-live');
  });
}
