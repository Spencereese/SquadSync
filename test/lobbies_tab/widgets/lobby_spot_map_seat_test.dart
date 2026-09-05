import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_spot_map_seat.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  test('kind maps empty, filled, and peacock without occupancy overlap', () {
    expect(
      lobbySpotMapKindFor(hasOccupant: false),
      LobbySpotMapKind.empty,
    );
    expect(
      lobbySpotMapKindFor(hasOccupant: true),
      LobbySpotMapKind.filled,
    );
    expect(
      lobbySpotMapKindFor(hasOccupant: false, peacockOffered: true),
      LobbySpotMapKind.peacock,
    );
    expect(
      lobbySpotMapKindFor(hasOccupant: true, peacockOffered: true),
      LobbySpotMapKind.filled,
    );
  });

  test('peacock chrome is thicker than filled, filled thicker than empty', () {
    expect(
      LobbySpotMapSeat.borderWidthFor(LobbySpotMapKind.peacock),
      greaterThan(LobbySpotMapSeat.borderWidthFor(LobbySpotMapKind.filled)),
    );
    expect(
      LobbySpotMapSeat.borderWidthFor(LobbySpotMapKind.filled),
      greaterThan(LobbySpotMapSeat.borderWidthFor(LobbySpotMapKind.empty)),
    );
    expect(
      LobbySpotMapSeat.accentFor(LobbySpotMapKind.empty),
      Colors.tealAccent,
    );
    expect(
      LobbySpotMapSeat.accentFor(LobbySpotMapKind.filled),
      Colors.greenAccent,
    );
    expect(
      LobbySpotMapSeat.accentFor(LobbySpotMapKind.peacock),
      Colors.cyanAccent,
    );
  });

  testWidgets('empty seat reads OPEN at arm length and keeps Call CTA',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        LobbySpotMapSeat(
          index: 0,
          kind: LobbySpotMapKind.empty,
          statusLabel: 'Open',
          trailing: ElevatedButton.icon(
            key: const Key('empty-spot-call-button'),
            onPressed: () {},
            icon: const Icon(Icons.call, size: 16),
            label: const Text('Call'),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('spot-map-seat-empty')), findsOneWidget);
    expect(find.byKey(const Key('spot-map-seat-filled')), findsNothing);
    expect(find.byKey(const Key('spot-map-seat-peacock')), findsNothing);
    expect(find.text('OPEN'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('PEACOCK'), findsNothing);
    expect(find.text('Spot 1'), findsOneWidget);
    expect(find.byKey(const Key('empty-spot-call-button')), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);

    final primary =
        tester.widget<Text>(find.byKey(const Key('spot-map-primary')));
    expect(primary.data, 'OPEN');
    expect(primary.style?.fontSize, greaterThanOrEqualTo(18));
    expect(primary.style?.fontWeight, FontWeight.w800);
    expect(primary.style?.color, Colors.tealAccent);

    final material =
        tester.widget<Material>(find.byKey(const Key('spot-map-seat-empty')));
    final shape = material.shape as RoundedRectangleBorder;
    expect(
      shape.side.width,
      LobbySpotMapSeat.borderWidthFor(LobbySpotMapKind.empty),
    );
  });

  testWidgets('filled seat reads occupant name over spot number',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LobbySpotMapSeat(
          index: 1,
          kind: LobbySpotMapKind.filled,
          statusLabel: 'Occupied',
          displayName: 'Alice',
        ),
      ),
    );

    expect(find.byKey(const Key('spot-map-seat-filled')), findsOneWidget);
    expect(find.byKey(const Key('spot-map-seat-empty')), findsNothing);
    expect(find.byKey(const Key('spot-map-seat-peacock')), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('OPEN'), findsNothing);
    expect(find.text('PEACOCK'), findsNothing);
    expect(find.text('Spot 2'), findsOneWidget);
    expect(find.text('Occupied'), findsOneWidget);

    final primary =
        tester.widget<Text>(find.byKey(const Key('spot-map-primary')));
    expect(primary.data, 'Alice');
    expect(primary.style?.fontSize, greaterThanOrEqualTo(18));
    expect(primary.style?.fontWeight, FontWeight.w800);
    expect(primary.style?.color, Colors.white);

    final material =
        tester.widget<Material>(find.byKey(const Key('spot-map-seat-filled')));
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, Colors.greenAccent);
    expect(
      shape.side.width,
      LobbySpotMapSeat.borderWidthFor(LobbySpotMapKind.filled),
    );
  });

  testWidgets('peacock seat reads PEACOCK with cyan glow chrome',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LobbySpotMapSeat(
          index: 2,
          kind: LobbySpotMapKind.peacock,
          statusLabel: 'Peacock',
        ),
      ),
    );

    expect(find.byKey(const Key('spot-map-seat-peacock')), findsOneWidget);
    expect(find.byKey(const Key('spot-map-seat-empty')), findsNothing);
    expect(find.byKey(const Key('spot-map-seat-filled')), findsNothing);
    expect(find.text('PEACOCK'), findsOneWidget);
    expect(find.text('Peacock'), findsOneWidget);
    expect(find.text('OPEN'), findsNothing);
    expect(find.text('Spot 3'), findsOneWidget);

    final primary =
        tester.widget<Text>(find.byKey(const Key('spot-map-primary')));
    expect(primary.data, 'PEACOCK');
    expect(primary.style?.fontSize, greaterThanOrEqualTo(18));
    expect(primary.style?.fontWeight, FontWeight.w800);
    expect(primary.style?.color, Colors.cyanAccent);
    expect(primary.style?.letterSpacing, greaterThan(1));

    final material =
        tester.widget<Material>(find.byKey(const Key('spot-map-seat-peacock')));
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, Colors.cyanAccent);
    expect(
      shape.side.width,
      LobbySpotMapSeat.borderWidthFor(LobbySpotMapKind.peacock),
    );
  });
}
