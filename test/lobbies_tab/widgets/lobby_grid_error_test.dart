import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_grid.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/widgets/lobby_surface_feedback.dart';

class _ErrorLobbyNotifier extends LobbyNotifier {
  @override
  Future<LobbyState> build() async {
    throw Exception('offline');
  }
}

void main() {
  testWidgets('lobby grid error is not a blank screen and offers retry',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lobbyNotifierProvider.overrideWith(_ErrorLobbyNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                LobbyGrid(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('lobby-grid-error')), findsOneWidget);
    expect(find.text("Couldn't load seats"), findsOneWidget);
    expect(find.text(kLobbySurfaceErrorHint), findsOneWidget);
    expect(find.text(kLobbySurfaceRetryLabel), findsOneWidget);
    expect(find.byKey(const Key('lock-retry')), findsOneWidget);
    expect(find.textContaining('Error:'), findsNothing);
  });
}
