import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:squad_sync/widgets/session_clip_playback.dart';

void main() {
  SessionClip attached({
    String clipId = 'clip-1',
    String? videoUrl = '/tmp/clutch.mp4',
    String? fileName = 'clutch.mp4',
    String? title,
  }) {
    return reduceSessionClip(
      current: SessionClip.empty,
      event: SessionClipEvent.attach,
      clipId: clipId,
      videoUrl: videoUrl,
      fileName: fileName,
      title: title,
    );
  }

  testWidgets('openSessionClipMedia is a no-op without video_url',
      (tester) async {
    var shown = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              shown = await openSessionClipMedia(
                context,
                attached(videoUrl: null),
                playerBuilder: (_) => fail('player should not build'),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(shown, isFalse);
    expect(find.byKey(const Key('session-clip-playback')), findsNothing);
  });

  testWidgets('opens existing-media playback dialog for a gallery clip',
      (tester) async {
    var playerUrl = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              openSessionClipMedia(
                context,
                attached(),
                playerBuilder: (url) {
                  playerUrl = url;
                  return const SizedBox(
                    key: Key('session-clip-player-stub'),
                    height: 80,
                  );
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

    expect(find.byKey(const Key('session-clip-playback')), findsOneWidget);
    expect(find.byKey(const Key('session-clip-player-stub')), findsOneWidget);
    expect(find.text('clutch.mp4'), findsOneWidget);
    expect(find.byKey(const Key('session-clip-playback-open')), findsNothing);
    expect(playerUrl, '/tmp/clutch.mp4');

    await tester.tap(find.byKey(const Key('session-clip-playback-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-clip-playback')), findsNothing);
  });

  testWidgets('network clip offers Open via existing url_launcher path',
      (tester) async {
    Uri? launched;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              openSessionClipMedia(
                context,
                attached(
                  videoUrl: 'https://cdn.example/ace.mp4',
                  title: 'Ace',
                ),
                playerBuilder: (_) => const SizedBox(height: 40),
                launchUrlFn: (uri) async {
                  launched = uri;
                  return true;
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

    expect(find.text('Ace'), findsOneWidget);
    expect(find.byKey(const Key('session-clip-playback-open')), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-clip-playback-open')));
    await tester.pump();
    expect(launched, Uri.parse('https://cdn.example/ace.mp4'));
  });

  testWidgets('missing clip dialog is empty, not a crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionClipPlaybackDialog(
          clip: attached(videoUrl: null),
          playerBuilder: (_) => fail('player should not build'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('session-clip-playback')), findsOneWidget);
    expect(find.byKey(const Key('session-clip-missing')), findsOneWidget);
    expect(find.text(kSessionClipMissingCopy), findsOneWidget);
    expect(find.text(kSessionClipMissingHint), findsOneWidget);
    expect(find.byKey(const Key('session-clip-player-retry')), findsNothing);
    expect(find.byKey(const Key('session-clip-playback-open')), findsNothing);
  });

  testWidgets('offline network clip offers retry instead of a hang',
      (tester) async {
    var playerBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SessionClipPlaybackDialog(
          clip: attached(
            videoUrl: 'https://cdn.example/ace.mp4',
            title: 'Ace',
          ),
          isOffline: true,
          playerBuilder: (_) {
            playerBuilds++;
            return const SizedBox(
              key: Key('session-clip-player-stub'),
              height: 40,
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('session-clip-offline')), findsOneWidget);
    expect(find.text(kSessionClipOfflineHint), findsOneWidget);
    expect(find.byKey(const Key('session-clip-offline-retry')), findsOneWidget);
    expect(playerBuilds, 0);

    await tester.tap(find.byKey(const Key('session-clip-offline-retry')));
    await tester.pump();

    expect(find.byKey(const Key('session-clip-player-stub')), findsOneWidget);
    expect(playerBuilds, 1);
    expect(find.byKey(const Key('session-clip-offline')), findsNothing);
  });

  testWidgets('player load failure offers retry', (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionClipPlayer(
            url: 'https://cdn.example/ace.mp4',
            initialize: () async {
              loads++;
              if (loads == 1) throw Exception('decode failed');
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('session-clip-player-error')), findsOneWidget);
    expect(find.text(kSessionClipLoadFailedCopy), findsOneWidget);
    expect(find.byKey(const Key('session-clip-player-retry')), findsOneWidget);
    expect(loads, 1);

    await tester.tap(find.byKey(const Key('session-clip-player-retry')));
    await tester.pump();
    await tester.pump();

    expect(loads, 2);
    expect(find.byKey(const Key('session-clip-player')), findsOneWidget);
    expect(find.byKey(const Key('session-clip-player-error')), findsNothing);
  });

  testWidgets('player offline error retry re-attempts load', (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionClipPlayer(
            url: 'https://cdn.example/ace.mp4',
            isOffline: true,
            initialize: () async {
              loads++;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('session-clip-offline')), findsOneWidget);
    expect(find.byKey(const Key('session-clip-offline-retry')), findsOneWidget);
    expect(loads, 0);

    await tester.tap(find.byKey(const Key('session-clip-offline-retry')));
    await tester.pump();
    await tester.pump();

    expect(loads, 1);
    expect(find.byKey(const Key('session-clip-player')), findsOneWidget);
  });

  testWidgets('empty You/stats last-5 open is a no-op, not a crash',
      (tester) async {
    var shown = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              shown = await openSessionClipFromYouStats(
                context,
                sessions: const [],
                playerBuilder: (_) => fail('player should not build'),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(shown, isFalse);
    expect(find.byKey(const Key('session-clip-playback')), findsNothing);
  });
}
