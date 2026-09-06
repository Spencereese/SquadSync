import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_header.dart';

Future<void> _pumpShareButton(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onPressed,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return LobbyShareButton(
              onPressed: () => onPressed(context),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'lobby share button payload includes app scheme and https fallback',
    (tester) async {
      String? copied;
      String? shared;
      await _pumpShareButton(
        tester,
        onPressed: (context) async {
          final result = await shareLobbyLink(
            lobbyId: 'lobby-9',
            copy: (text) async => copied = text,
            share: (text) async => shared = text,
          );
          presentLobbyShare(context, result);
        },
      );

      expect(find.byKey(const Key('lobby-share-link')), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byTooltip('Share lobby'), findsOneWidget);

      await tester.tap(find.byKey(const Key('lobby-share-link')));
      await tester.pump();

      expect(
        copied,
        'codsquadapp://lobby/lobby-9\nhttps://codsquad.app/l/lobby-9',
      );
      expect(shared, copied);
      expect(copied, contains(lobbyShareDeepLink(lobbyId: 'lobby-9')));
      expect(copied, contains(lobbyShareHttpsLink(lobbyId: 'lobby-9')));
      for (final line in copied!.split('\n')) {
        expect(locationForDeepLink(line), '/squad?lobby_id=lobby-9');
      }
      expect(find.text(kLobbyShareCopiedCopy), findsOneWidget);
      expect(find.byKey(const Key('lobby-share-copied')), findsOneWidget);
    },
  );

  testWidgets('share with no lobby id shows empty error, not copied',
      (tester) async {
    var copied = false;
    var shared = false;
    await _pumpShareButton(
      tester,
      onPressed: (context) async {
        final result = await shareLobbyLink(
          lobbyId: '',
          copy: (_) async => copied = true,
          share: (_) async => shared = true,
        );
        presentLobbyShare(context, result);
      },
    );

    await tester.tap(find.byKey(const Key('lobby-share-link')));
    await tester.pump();

    expect(copied, isFalse);
    expect(shared, isFalse);
    expect(find.text(kLobbyShareEmptyCopy), findsOneWidget);
    expect(find.byKey(const Key('lobby-share-empty')), findsOneWidget);
    expect(find.text(kLobbyShareCopiedCopy), findsNothing);
  });

  testWidgets('clipboard failure shows copy error, not copied toast',
      (tester) async {
    var shared = false;
    await _pumpShareButton(
      tester,
      onPressed: (context) async {
        final result = await shareLobbyLink(
          lobbyId: 'lobby-9',
          copy: (_) async => throw Exception('denied'),
          share: (_) async => shared = true,
        );
        presentLobbyShare(context, result);
      },
    );

    await tester.tap(find.byKey(const Key('lobby-share-link')));
    await tester.pump();

    expect(shared, isFalse);
    expect(find.text(kLobbyShareCopiedCopy), findsNothing);
    expect(
        find.text('$kLobbyShareClipboardFailedCopy: denied'), findsOneWidget);
    expect(
      find.byKey(const Key('lobby-share-clipboard-failed')),
      findsOneWidget,
    );
  });
}
