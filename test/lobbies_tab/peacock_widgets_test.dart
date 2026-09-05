import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/lobbies_tab/peacock_widgets.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  testWidgets('preferred chips toggle selected game', (tester) async {
    final preferred = <String>{};
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return PreferredPeacockGamesChips(
              games: const ['Warzone', 'MW2'],
              preferred: preferred,
              onToggle: (name) => setState(() {
                if (!preferred.add(name)) preferred.remove(name);
              }),
            );
          },
        ),
      ),
    );

    expect(find.byKey(const Key('preferred-peacock-games')), findsOneWidget);
    expect(find.text(PreferredPeacockGamesChips.titleLabel), findsOneWidget);
    expect(find.byKey(const Key('preferred-peacock-game-Warzone')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('preferred-peacock-game-Warzone')));
    await tester.pump();
    expect(preferred, {'Warzone'});

    final selected = tester.widget<FilterChip>(
      find.byKey(const Key('preferred-peacock-game-Warzone')),
    );
    expect(selected.selected, isTrue);

    await tester.tap(find.byKey(const Key('preferred-peacock-game-Warzone')));
    await tester.pump();
    expect(preferred, isEmpty);
  });

  testWidgets('empty games shows empty copy', (tester) async {
    await tester.pumpWidget(
      wrap(
        PreferredPeacockGamesChips(
          games: const [],
          preferred: const {},
          onToggle: (_) {},
        ),
      ),
    );
    expect(
        find.byKey(const Key('preferred-peacock-games-empty')), findsOneWidget);
    expect(find.text(PreferredPeacockGamesChips.emptyLabel), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
  });
}
