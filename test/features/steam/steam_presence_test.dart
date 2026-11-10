import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/steam/ui/steam_link_field.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/steam/data/fake_steam_repository.dart';
import 'package:squadsync/features/steam/domain/steam_presence.dart';
import 'package:squadsync/features/steam/ui/steam_presence_lines.dart';

Widget _lines(SteamRepositoryOverride steam) {
  return ProviderScope(
    overrides: [steamRepositoryProvider.overrideWithValue(steam.repo)],
    child: MaterialApp(
      home: Scaffold(body: SteamPresenceLines(members: steam.members)),
    ),
  );
}

class SteamRepositoryOverride {
  SteamRepositoryOverride(this.repo, this.members);
  final FakeSteamRepository repo;
  final List<Member> members;
}

void main() {
  test('a steam game is labelled via Steam and is not a check-in', () {
    expect(
      steamStatusLine(
        const SteamMember(
          userId: 'alex',
          view: SteamView.playing,
          game: 'Halo Infinite',
        ),
        setUp: true,
      ),
      'Playing Halo Infinite · via Steam',
    );
    expect(
      steamStatusLine(
        const SteamMember(userId: 'alex', view: SteamView.notInGame),
        setUp: true,
      ),
      isNull,
    );
    expect(
      steamSpokenLine('Alex', 'Playing Halo Infinite · via Steam'),
      'Alex, playing Halo Infinite via Steam',
    );
  });

  testWidgets('each steam state has its own honest line', (tester) async {
    Future<void> show(FakeSteamRepository repo) async {
      await tester.pumpWidget(
        _lines(
          SteamRepositoryOverride(repo, const [
            Member(id: 'alex', displayName: 'Alex', defaultGame: 'Halo'),
          ]),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(FakeSteamRepository());
    expect(find.text('Steam presence not set up yet'), findsOneWidget);
    expect(find.byKey(const Key('steam-not-set-up')), findsOneWidget);

    await show(
      FakeSteamRepository(
        board: const SteamBoard(
          setUp: true,
          members: [SteamMember(userId: 'alex', view: SteamView.notLinked)],
        ),
      ),
    );
    expect(find.text('Steam not linked'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Alex, Steam not linked')),
      findsOneWidget,
    );

    await show(
      FakeSteamRepository(
        board: const SteamBoard(
          setUp: true,
          members: [
            SteamMember(userId: 'alex', view: SteamView.privateProfile),
          ],
        ),
      ),
    );
    expect(find.text('Steam profile private'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Steam profile private')),
      findsOneWidget,
    );

    await show(
      FakeSteamRepository(
        board: const SteamBoard(
          setUp: true,
          members: [
            SteamMember(
              userId: 'alex',
              view: SteamView.playing,
              game: 'Halo Infinite',
            ),
          ],
        ),
      ),
    );
    expect(find.text('Playing Halo Infinite · via Steam'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Alex, playing Halo Infinite via Steam'),
      findsOneWidget,
    );
    expect(find.textContaining('checked in'), findsNothing);
  });

  testWidgets(
    'the profile links a SteamID64 and says when Steam is not set up',
    (tester) async {
      final steam = FakeSteamRepository(acceptsLinks: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [steamRepositoryProvider.overrideWithValue(steam)],
          child: const MaterialApp(home: Scaffold(body: SteamLinkField())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Steam not linked'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('steam-link')),
        '76561198000000001',
      );
      await tester.tap(find.byKey(const Key('steam-link-save')));
      await tester.pumpAndSettle();
      expect(find.text('Linked 76561198000000001'), findsOneWidget);

      steam.acceptsLinks = false;
      await tester.enterText(find.byKey(const Key('steam-link')), 'example');
      await tester.tap(find.byKey(const Key('steam-link-save')));
      await tester.pumpAndSettle();
      expect(find.text('Steam presence not set up yet'), findsWidgets);
    },
  );
}
