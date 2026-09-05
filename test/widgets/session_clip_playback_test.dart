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
                playerBuilder: (_) {
                  fail('player should not build');
                  return const SizedBox.shrink();
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
}
