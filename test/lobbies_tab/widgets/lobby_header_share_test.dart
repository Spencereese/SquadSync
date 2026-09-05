import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_header.dart';

void main() {
  testWidgets(
    'lobby share button payload includes app scheme and https fallback',
    (tester) async {
      String? copied;
      String? shared;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LobbyShareButton(
              onPressed: () async {
                await shareLobbyLink(
                  lobbyId: 'lobby-9',
                  copy: (text) async => copied = text,
                  share: (text) async => shared = text,
                );
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('lobby-share-link')), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byTooltip('Share lobby'), findsOneWidget);

      await tester.tap(find.byKey(const Key('lobby-share-link')));
      await tester.pump();

      expect(copied, 'codsquadapp://lobby/lobby-9\nhttps://codsquad.app/l/lobby-9');
      expect(shared, copied);
      expect(copied, contains(lobbyShareDeepLink(lobbyId: 'lobby-9')));
      expect(copied, contains(lobbyShareHttpsLink(lobbyId: 'lobby-9')));
      for (final line in copied!.split('\n')) {
        expect(locationForDeepLink(line), '/squad?lobby_id=lobby-9');
      }
    },
  );
}
