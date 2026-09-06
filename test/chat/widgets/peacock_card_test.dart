import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/widgets/peacock_card.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
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

class _FilledLobbyNotifier extends LobbyNotifier {
  @override
  Future<LobbyState> build() async {
    final lobby = Lobby.create(
      name: 'Squad',
      gameName: 'Warzone',
      maxSpots: 4,
      createdBy: 'u1',
    ).copyWith(id: 'lobby-9');
    return LobbyState.initial().copyWith(
      selectedLobbyId: 'lobby-9',
      currentLobby: lobby,
      currentGame: const {'name': 'Warzone', 'maxSpots': 4},
      gameLobbySpots: {
        'Warzone': ['u1', null, null, null],
      },
    );
  }
}

Future<void> _pumpHost(
  WidgetTester tester,
  LobbyNotifier Function() create, {
  int? spotIndex,
  void Function(String location)? go,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        lobbyNotifierProvider.overrideWith(create),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ChatPeacockCardHost(spotIndex: spotIndex, go: go),
        ),
      ),
    ),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('filled card tap uses the same lobby router as notifications',
      (tester) async {
    String? opened;
    await tester.pumpWidget(
      _wrap(
        ChatPeacockCard(
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
          claimed: 1,
          maxSpots: 4,
          spotIndex: 2,
          go: (location) => opened = location,
        ),
      ),
    );

    expect(find.byKey(const Key('peacock-card')), findsOneWidget);
    expect(
      find.text('Your Active Lobby: Warzone - 1/4 spots'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('peacock-card-empty')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('peacock-card')));
    await tester.pump();
    expect(opened, '/squad/Warzone?lobby_id=lobby-9&spot_index=2');
  });

  testWidgets('empty card shows empty copy, not a spinner or retry',
      (tester) async {
    String? opened;
    await tester.pumpWidget(
      _wrap(
        ChatPeacockCard(
          phase: LobbySurfacePhase.empty,
          go: (location) => opened = location,
        ),
      ),
    );

    expect(find.byKey(const Key('peacock-card-empty')), findsOneWidget);
    expect(find.text('No active lobby'), findsOneWidget);
    expect(find.text(kPeacockCardEmptyHint), findsOneWidget);
    expect(find.byKey(const Key('peacock-card-empty-hint')), findsOneWidget);
    expect(find.byKey(const Key('peacock-card')), findsNothing);
    expect(find.byKey(const Key('peacock-card-retry')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('peacock-card-empty')));
    await tester.pump();
    expect(opened, isNull);
  });

  testWidgets('offline card offers Retry and never navigates', (tester) async {
    var retried = false;
    String? opened;
    await tester.pumpWidget(
      _wrap(
        ChatPeacockCard(
          phase: LobbySurfacePhase.error,
          isOffline: true,
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
          spotIndex: 2,
          onRetry: () => retried = true,
          go: (location) => opened = location,
        ),
      ),
    );

    expect(find.byKey(const Key('peacock-card-error')), findsOneWidget);
    expect(find.text(kLobbySurfaceOfflineCopy), findsOneWidget);
    expect(find.text(kLobbySurfaceErrorHint), findsOneWidget);
    expect(find.text(kLobbySurfaceRetryLabel), findsOneWidget);
    expect(find.byKey(const Key('peacock-card-retry')), findsOneWidget);
    expect(find.byKey(const Key('peacock-card-empty')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('peacock-card-retry')));
    await tester.pump();
    expect(retried, isTrue);
    expect(opened, isNull);
  });

  testWidgets('load failure offers Retry, not empty', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        ChatPeacockCard(
          phase: LobbySurfacePhase.error,
          error: 'denied',
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.byKey(const Key('peacock-card-error')), findsOneWidget);
    expect(find.text("Couldn't load peacock"), findsOneWidget);
    expect(find.text('denied'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('peacock-card-retry')));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('loading is in-flight copy, not empty', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ChatPeacockCard(phase: LobbySurfacePhase.loading),
      ),
    );

    expect(find.byKey(const Key('peacock-card-loading')), findsOneWidget);
    expect(find.text('Loading peacock...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('peacock-card-empty')), findsNothing);
    expect(find.byKey(const Key('peacock-card-error')), findsNothing);
  });

  group('ChatPeacockCardHost empty / error / offline', () {
    testWidgets('empty host when no lobby is picked', (tester) async {
      await _pumpHost(tester, _EmptyLobbyNotifier.new);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('peacock-card-empty')), findsOneWidget);
      expect(find.text('No active lobby'), findsOneWidget);
      expect(find.byKey(const Key('peacock-card')), findsNothing);
      expect(find.byKey(const Key('peacock-card-retry')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('offline host offers Retry, not empty or a hung spinner',
        (tester) async {
      await _pumpHost(tester, _OfflineLobbyNotifier.new);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('peacock-card-error')), findsOneWidget);
      expect(find.text(kLobbySurfaceOfflineCopy), findsOneWidget);
      expect(find.text(kLobbySurfaceRetryLabel), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('peacock-card-empty')), findsNothing);
      expect(find.textContaining('SocketException'), findsNothing);
    });

    testWidgets('load failure host offers Retry and never a blank card',
        (tester) async {
      await _pumpHost(tester, _DeniedLobbyNotifier.new);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('peacock-card-error')), findsOneWidget);
      expect(find.text("Couldn't load peacock"), findsOneWidget);
      expect(find.byKey(const Key('peacock-card-retry')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('loading host is in-flight copy, not empty', (tester) async {
      await _pumpHost(tester, _LoadingLobbyNotifier.new);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('peacock-card-loading')), findsOneWidget);
      expect(find.text('Loading peacock...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('peacock-card-empty')), findsNothing);
    });

    testWidgets('Retry re-fetches and can settle empty, not a hang',
        (tester) async {
      _OfflineThenEmptyLobbyNotifier.builds = 0;
      await _pumpHost(tester, _OfflineThenEmptyLobbyNotifier.new);
      await tester.pump();
      await tester.pump();

      expect(find.text(kLobbySurfaceOfflineCopy), findsOneWidget);

      await tester.tap(find.byKey(const Key('peacock-card-retry')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('peacock-card-empty')), findsOneWidget);
      expect(find.text('No active lobby'), findsOneWidget);
      expect(find.byKey(const Key('peacock-card-error')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('filled host tap opens the shared lobby location',
        (tester) async {
      String? opened;
      await _pumpHost(
        tester,
        _FilledLobbyNotifier.new,
        spotIndex: 2,
        go: (location) => opened = location,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('peacock-card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('peacock-card')));
      await tester.pump();
      expect(opened, '/squad/Warzone?lobby_id=lobby-9&spot_index=2');
    });
  });
}
