import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/lobbies_tab/peacock_widgets.dart';
import 'package:squad_sync/services/preferred_peacock_games.dart';

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
    expect(find.byKey(const Key('preferred-peacock-games-empty-selected')),
        findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no games selected shows empty copy and keeps chips',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        PreferredPeacockGamesChips(
          games: const ['Warzone', 'MW2'],
          preferred: const {},
          onToggle: (_) {},
        ),
      ),
    );
    expect(find.byType(FilterChip), findsNWidgets(2));
    expect(
      find.byKey(const Key('preferred-peacock-games-empty-selected')),
      findsOneWidget,
    );
    expect(
      find.text(kPreferredPeacockFilterNoGamesSelectedCopy),
      findsOneWidget,
    );
    expect(
      find.text(kPreferredPeacockFilterNoGamesSelectedHint),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('preferred-peacock-games-empty')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('preferred-peacock-games-empty-matches')),
      findsNothing,
    );
  });

  testWidgets('no matching offers shows empty-matches copy', (tester) async {
    await tester.pumpWidget(
      wrap(
        PreferredPeacockGamesChips(
          games: const ['Warzone', 'MW2'],
          preferred: const {'Warzone'},
          offerGameNames: const ['Fortnite'],
          onToggle: (_) {},
        ),
      ),
    );
    expect(find.byType(FilterChip), findsNWidgets(2));
    expect(
      find.byKey(const Key('preferred-peacock-games-empty-matches')),
      findsOneWidget,
    );
    expect(find.text(kPreferredPeacockFilterNoMatchesCopy), findsOneWidget);
    expect(find.text(kPreferredPeacockFilterNoMatchesHint), findsOneWidget);
    expect(
      find.byKey(const Key('preferred-peacock-games-empty-selected')),
      findsNothing,
    );
  });

  testWidgets('error copy offers Retry and never a spinner', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        PreferredPeacockGamesChips(
          games: const ['Warzone'],
          preferred: const {'Warzone'},
          error: Exception('offline'),
          onRetry: () => retried = true,
          onToggle: (_) {},
        ),
      ),
    );

    expect(
      find.byKey(const Key('preferred-peacock-games-error')),
      findsOneWidget,
    );
    expect(find.text(kPreferredPeacockFilterErrorCopy), findsOneWidget);
    expect(find.text(kPreferredPeacockFilterErrorHint), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    expect(
      find.byKey(const Key('preferred-peacock-games-retry')),
      findsOneWidget,
    );
    expect(find.text(kPreferredPeacockFilterRetryLabel), findsOneWidget);
    expect(find.byType(FilterChip), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byKey(const Key('preferred-peacock-games-empty')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('preferred-peacock-games-empty-selected')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('preferred-peacock-games-empty-matches')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('preferred-peacock-games-retry')));
    await tester.pump();
    expect(retried, isTrue);
  });
}
