import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/screens/components/chat_info_actions.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_controls.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/widgets/lobby_surface_feedback.dart';

class _EmptyLobbyNotifier extends LobbyNotifier {
  @override
  Future<LobbyState> build() async => LobbyState.initial();
}

class _DeniedLobbyNotifier extends LobbyNotifier {
  @override
  Future<LobbyState> build() async {
    throw Exception('denied');
  }
}

class _OfflineLobbyNotifier extends LobbyNotifier {
  @override
  Future<LobbyState> build() async {
    throw Exception('SocketException: Failed host lookup');
  }
}

class _LoadingLobbyNotifier extends LobbyNotifier {
  @override
  Future<LobbyState> build() => Completer<LobbyState>().future;
}

class _OfflineThenEmptyLobbyNotifier extends LobbyNotifier {
  static int builds = 0;

  @override
  Future<LobbyState> build() async {
    builds++;
    if (builds == 1) throw Exception('offline');
    return LobbyState.initial();
  }
}

Future<void> _pumpControls(
  WidgetTester tester,
  LobbyNotifier Function() create,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        lobbyNotifierProvider.overrideWith(create),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [LobbyControls()],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'lobby Tonight block groups I am on / LFG / Invite; Voice under More',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TonightActionsBlock(
                children: tonightStripChildren(
                  onNow: const Text("I'm on now"),
                  lookingForSquad: const Text('Looking for Squad'),
                  invite: const Text('Invite'),
                ),
              ),
              MoreActionsBlock(
                children: [
                  if (slotForTonightAction(kMoreVoiceAction) ==
                      TonightStripSlot.more)
                    const Text('Voice'),
                  if (slotForTonightAction(kDeadSearchAction) != null)
                    const Text('Search'),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('tonight-actions')), findsOneWidget);
    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text("I'm on now"), findsOneWidget);
    expect(find.text('Looking for Squad'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Voice'), findsNothing);
    expect(find.text('Search'), findsNothing);

    await tester.tap(find.byKey(const Key('more-actions-toggle')));
    await tester.pump();

    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Search'), findsNothing);
  });

  group('LobbyControls Tonight empty / error / offline', () {
    testWidgets('empty strip when no lobby is picked', (tester) async {
      await _pumpControls(tester, _EmptyLobbyNotifier.new);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('tonight-empty')), findsOneWidget);
      expect(find.text('No lobby tonight'), findsOneWidget);
      expect(find.text(kTonightEmptyHint), findsOneWidget);
      expect(find.text("I'm on now"), findsNothing);
      expect(find.text('Looking for Squad'), findsNothing);
      expect(find.text('Invite'), findsNothing);
      expect(find.byKey(const Key('tonight-retry')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('load failure offers Retry and never a blank strip',
        (tester) async {
      await _pumpControls(tester, _DeniedLobbyNotifier.new);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('tonight-error')), findsOneWidget);
      expect(find.text("Couldn't load tonight"), findsOneWidget);
      expect(find.text(kLobbySurfaceErrorHint), findsOneWidget);
      expect(find.text(kLobbySurfaceRetryLabel), findsOneWidget);
      expect(find.byKey(const Key('tonight-retry')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("I'm on now"), findsNothing);
    });

    testWidgets('offline offers Retry, not empty or a hung spinner',
        (tester) async {
      await _pumpControls(tester, _OfflineLobbyNotifier.new);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('tonight-error')), findsOneWidget);
      expect(find.text(kLobbySurfaceOfflineCopy), findsOneWidget);
      expect(find.text(kLobbySurfaceErrorHint), findsOneWidget);
      expect(find.text(kLobbySurfaceRetryLabel), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('tonight-empty')), findsNothing);
      expect(find.textContaining('SocketException'), findsNothing);
    });

    testWidgets('loading is in-flight copy, not empty', (tester) async {
      await _pumpControls(tester, _LoadingLobbyNotifier.new);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('tonight-loading')), findsOneWidget);
      expect(find.text('Loading tonight...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('tonight-empty')), findsNothing);
      expect(find.byKey(const Key('tonight-error')), findsNothing);
      expect(find.text("I'm on now"), findsNothing);
    });

    testWidgets('Retry re-fetches and can settle empty, not a hang',
        (tester) async {
      _OfflineThenEmptyLobbyNotifier.builds = 0;
      await _pumpControls(tester, _OfflineThenEmptyLobbyNotifier.new);
      await tester.pump();
      await tester.pump();

      expect(find.text(kLobbySurfaceOfflineCopy), findsOneWidget);

      await tester.tap(find.byKey(const Key('tonight-retry')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('tonight-empty')), findsOneWidget);
      expect(find.text('No lobby tonight'), findsOneWidget);
      expect(find.byKey(const Key('tonight-error')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
