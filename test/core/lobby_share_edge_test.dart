import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_header.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_seat_affordance.dart';

/// Ticket 62: remaining lobby share/copy edge units.
/// Pairs with tickets 24/47. No QR / SMS / Universal Links hosting.
void main() {
  const payload = 'codsquadapp://lobby/lobby-9\nhttps://codsquad.app/l/lobby-9';

  Future<void> pumpShare(WidgetTester tester, LobbyShareResult result) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return LobbyShareButton(
                onPressed: () => presentLobbyShare(context, result),
              );
            },
          ),
        ),
      ),
    );
  }

  group('share sheet cancel', () {
    test('ShareResult dismissed is cancelled, not copied', () {
      const dismissed = ShareResult('', ShareResultStatus.dismissed);
      expect(lobbyShareIsCancelled(dismissed), isTrue);
      expect(
        lobbyShareSheetOutcome(dismissed),
        LobbyShareOutcome.cancelled,
      );
      expect(
        lobbyShareSheetOutcome(const LobbyShareSheetCancelled()),
        LobbyShareOutcome.cancelled,
      );
      expect(lobbyShareIsCancelled(Exception('sheet dismissed')), isTrue);
      expect(lobbyShareIsCancelled(Exception('User cancelled')), isTrue);
    });

    test('ShareResult success / unavailable stay success after copy', () {
      expect(
        lobbyShareSheetOutcome(
          const ShareResult('messages', ShareResultStatus.success),
        ),
        LobbyShareOutcome.success,
      );
      expect(
        lobbyShareSheetOutcome(ShareResult.unavailable),
        LobbyShareOutcome.success,
      );
      expect(lobbyShareIsCancelled(ShareResult.unavailable), isFalse);
    });

    test('shareLobbyLink dismissed sheet is cancelled after copy', () async {
      var shared = false;
      final copied = <String>[];
      final result = await shareLobbyLink(
        lobbyId: 'lobby-9',
        copy: (text) async => copied.add(text),
        share: (_) async {
          shared = true;
          throw const LobbyShareSheetCancelled();
        },
      );
      expect(result.outcome, LobbyShareOutcome.cancelled);
      expect(result.isCancelled, isTrue);
      expect(result.isSuccess, isFalse);
      expect(copied, [payload]);
      expect(shared, isTrue);
      expect(result.payload, payload);
      expect(lobbyShareMessage(result), isEmpty);
      expect(
        lobbyShareFeedbackKey(result.outcome),
        const Key('lobby-share-cancelled'),
      );
    });

    test('shareLobbyLink dismiss error string is cancelled after copy',
        () async {
      final copied = <String>[];
      final result = await shareLobbyLink(
        lobbyId: 'lobby-9',
        copy: (text) async => copied.add(text),
        share: (_) async => throw Exception('sheet dismissed'),
      );
      expect(result.outcome, LobbyShareOutcome.cancelled);
      expect(copied, [payload]);
      expect(lobbyShareMessage(result), isEmpty);
    });

    testWidgets('share sheet cancel is silent, not copied or error toast',
        (tester) async {
      await pumpShare(
        tester,
        const LobbyShareResult.cancelled(payload: payload),
      );
      await tester.tap(find.byKey(const Key('lobby-share-link')));
      await tester.pump();

      expect(find.text(kLobbyShareCopiedCopy), findsNothing);
      expect(find.text(kLobbyShareEmptyCopy), findsNothing);
      expect(find.text(kLobbyShareClipboardFailedCopy), findsNothing);
      expect(find.text(kLobbyShareOfflineCopy), findsNothing);
      expect(find.byKey(const Key('lobby-share-cancelled')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('copy failure', () {
    test('clipboard failure does not open the share sheet', () async {
      var shared = false;
      final result = await shareLobbyLink(
        lobbyId: 'lobby-9',
        copy: (_) async => throw Exception('denied'),
        share: (_) async => shared = true,
      );
      expect(result.outcome, LobbyShareOutcome.clipboardFailed);
      expect(result.isClipboardFailed, isTrue);
      expect(shared, isFalse);
      expect(result.payload, payload);
      expect(
        lobbyShareMessage(result),
        '$kLobbyShareClipboardFailedCopy: denied',
      );
    });

    test('clipboard failure with empty detail does not invent a reason',
        () async {
      final result = await shareLobbyLink(
        lobbyId: 'lobby-9',
        copy: (_) async => throw Exception('  '),
        share: (_) async {},
      );
      expect(result.outcome, LobbyShareOutcome.clipboardFailed);
      expect(lobbyShareErrorDetail(result.error), isEmpty);
      expect(lobbyShareMessage(result), kLobbyShareClipboardFailedCopy);
    });

    test('clipboard failure with null error keeps the arm-length copy', () {
      const result = LobbyShareResult.clipboardFailed(payload: payload);
      expect(lobbyShareErrorDetail(result.error), isEmpty);
      expect(lobbyShareMessage(result), kLobbyShareClipboardFailedCopy);
      expect(
        lobbyShareFeedbackKey(result.outcome),
        const Key('lobby-share-clipboard-failed'),
      );
    });

    testWidgets('clipboard failure shows copy error, not copied toast',
        (tester) async {
      await pumpShare(
        tester,
        LobbyShareResult.clipboardFailed(
          error: Exception('denied'),
          payload: payload,
        ),
      );
      await tester.tap(find.byKey(const Key('lobby-share-link')));
      await tester.pump();

      expect(find.text(kLobbyShareCopiedCopy), findsNothing);
      expect(
        find.text('$kLobbyShareClipboardFailedCopy: denied'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lobby-share-clipboard-failed')),
        findsOneWidget,
      );
    });
  });

  group('empty lobby share payload', () {
    test('empty / whitespace payload is empty, not a host-only URI', () {
      expect(lobbySharePayload(lobbyId: ''), isEmpty);
      expect(lobbySharePayload(lobbyId: '   '), isEmpty);
      expect(lobbySharePayloadIsEmpty(null), isTrue);
      expect(lobbySharePayloadIsEmpty(''), isTrue);
      expect(lobbySharePayloadIsEmpty('   '), isTrue);
      expect(lobbySharePayloadIsEmpty(payload), isFalse);
    });

    test('shareLobbyLink empty payload does not copy or share', () async {
      var copied = false;
      var shared = false;
      for (final text in [null, '', '   ']) {
        copied = false;
        shared = false;
        final result = await shareLobbyLink(
          lobbyId: text == null ? '' : 'lobby-9',
          payload: text,
          copy: (_) async => copied = true,
          share: (_) async => shared = true,
        );
        expect(result.outcome, LobbyShareOutcome.empty, reason: '$text');
        expect(result.isEmpty, isTrue);
        expect(result.payload, isNull);
        expect(copied, isFalse);
        expect(shared, isFalse);
        expect(lobbyShareMessage(result), kLobbyShareEmptyCopy);
      }
    });

    test('empty-spot Invite empty payload is empty, not a link', () async {
      var copied = false;
      var shared = false;
      final result = await shareEmptySpotInvite(
        lobbyId: 'lobby-9',
        payload: '',
        copy: (_) async => copied = true,
        share: (_) async => shared = true,
      );
      expect(result.outcome, LobbyShareOutcome.empty);
      expect(copied, isFalse);
      expect(shared, isFalse);
    });

    test('empty wins over offline — no invented link', () async {
      var copied = false;
      final result = await shareLobbyLink(
        lobbyId: '  ',
        isOffline: true,
        copy: (_) async => copied = true,
        share: (_) async {},
      );
      expect(result.outcome, LobbyShareOutcome.empty);
      expect(result.isOffline, isFalse);
      expect(copied, isFalse);
      expect(lobbyShareMessage(result), kLobbyShareEmptyCopy);
    });

    testWidgets('empty payload shows no-lobby copy, not copied',
        (tester) async {
      await pumpShare(tester, const LobbyShareResult.empty());
      await tester.tap(find.byKey(const Key('lobby-share-link')));
      await tester.pump();

      expect(find.text(kLobbyShareEmptyCopy), findsOneWidget);
      expect(find.byKey(const Key('lobby-share-empty')), findsOneWidget);
      expect(find.text(kLobbyShareCopiedCopy), findsNothing);
    });
  });

  group('offline share/copy', () {
    test('offline flag does not copy or open the sheet', () async {
      var copied = false;
      var shared = false;
      final result = await shareLobbyLink(
        lobbyId: 'lobby-9',
        isOffline: true,
        copy: (_) async => copied = true,
        share: (_) async => shared = true,
      );
      expect(result.outcome, LobbyShareOutcome.offline);
      expect(result.isOffline, isTrue);
      expect(copied, isFalse);
      expect(shared, isFalse);
      expect(result.payload, payload);
      expect(lobbyShareMessage(result), kLobbyShareOfflineCopy);
      expect(
        lobbyShareFeedbackKey(result.outcome),
        const Key('lobby-share-offline'),
      );
    });

    test('copy network failure is offline, not clipboardFailed', () async {
      var shared = false;
      final result = await shareLobbyLink(
        lobbyId: 'lobby-9',
        copy: (_) async => throw Exception('Failed host lookup'),
        share: (_) async => shared = true,
      );
      expect(result.outcome, LobbyShareOutcome.offline);
      expect(result.isClipboardFailed, isFalse);
      expect(shared, isFalse);
      expect(
        lobbyShareMessage(result),
        '$kLobbyShareOfflineCopy: Failed host lookup',
      );
    });

    test('share network failure after copy is offline, not copied toast',
        () async {
      final copied = <String>[];
      final result = await shareLobbyLink(
        lobbyId: 'lobby-9',
        copy: (text) async => copied.add(text),
        share: (_) async => throw Exception('SocketException: network'),
      );
      expect(result.outcome, LobbyShareOutcome.offline);
      expect(copied, [payload]);
      expect(result.payload, payload);
      expect(lobbyShareIsOfflineError(result.error), isTrue);
      expect(lobbyShareMessage(result), contains(kLobbyShareOfflineCopy));
    });

    test('empty-spot Invite offline reuses shareLobbyLink', () async {
      var copied = false;
      final result = await shareEmptySpotInvite(
        lobbyId: 'lobby-9',
        isOffline: true,
        copy: (_) async => copied = true,
        share: (_) async {},
      );
      expect(result.outcome, LobbyShareOutcome.offline);
      expect(copied, isFalse);
      expect(lobbyShareMessage(result), kLobbyShareOfflineCopy);
    });

    test('offline classifier covers socket / network / lookup', () {
      expect(lobbyShareIsOfflineError(null), isFalse);
      expect(lobbyShareIsOfflineError(Exception('denied')), isFalse);
      expect(lobbyShareIsOfflineError(Exception('offline')), isTrue);
      expect(lobbyShareIsOfflineError(Exception('SocketException')), isTrue);
      expect(lobbyShareIsOfflineError(Exception('Failed host lookup')), isTrue);
      expect(lobbyShareIsOfflineError(Exception('connection refused')), isTrue);
      expect(lobbyShareIsOfflineError(Exception('ClientException')), isTrue);
    });

    testWidgets('offline share shows offline copy, not copied toast',
        (tester) async {
      await pumpShare(
        tester,
        const LobbyShareResult.offline(payload: payload),
      );
      await tester.tap(find.byKey(const Key('lobby-share-link')));
      await tester.pump();

      expect(find.text(kLobbyShareOfflineCopy), findsOneWidget);
      expect(find.byKey(const Key('lobby-share-offline')), findsOneWidget);
      expect(find.text(kLobbyShareCopiedCopy), findsNothing);
      expect(find.text(kLobbyShareEmptyCopy), findsNothing);
    });
  });
}
