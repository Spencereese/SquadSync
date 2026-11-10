import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/data/fake_auth_repository.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/invite/data/code_share.dart';
import 'package:squadsync/features/invite/data/fake_invite_repository.dart';
import 'package:squadsync/features/invite/domain/invite_code.dart';
import 'package:squadsync/features/invite/ui/invite_screen.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';

void main() {
  testWidgets('the owner can copy and share a code', (tester) async {
    final share = MemoryCodeShare();
    final invites = FakeInviteRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inviteRepositoryProvider.overrideWithValue(invites),
          codeShareProvider.overrideWithValue(share),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const MaterialApp(home: InviteScreen(demo: true)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('invite-demo')), findsOneWidget);
    expect(
      find.text('No code yet. Make one when you want a friend to join.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('invite-rotate')));
    await tester.pump();
    await tester.pump();

    expect(find.text('CODE2341'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-copy')));
    await tester.tap(find.byKey(const Key('invite-share')));
    await tester.pump();

    expect(share.copied, 'Join my SquadSync squad. Code: CODE2341');
    expect(share.shared, share.copied);
    expect(share.origin, isNotNull);
    expect(share.origin!.width, greaterThan(0));
    expect(share.origin!.height, greaterThan(0));
  });

  test('a zero share origin is replaced with a non-zero rect', () {
    expect(shareOrigin(null).width, greaterThan(0));
    expect(shareOrigin(null).height, greaterThan(0));
    expect(shareOrigin(Rect.zero), isNot(Rect.zero));
    const button = Rect.fromLTWH(12, 24, 80, 36);
    expect(shareOrigin(button), button);
  });

  testWidgets('a share failure says to use copy', (tester) async {
    final share = _ThrowingShare();
    final invites = FakeInviteRepository()
      ..invite = SquadInvite(
        code: 'CODE2345',
        expiresAt: DateTime.utc(2026, 11, 16, 8, 43),
        squadId: 'squad',
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inviteRepositoryProvider.overrideWithValue(invites),
          codeShareProvider.overrideWithValue(share),
          squadClockProvider.overrideWithValue(
            ManualSquadClock(DateTime.utc(2026, 11, 9)),
          ),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const MaterialApp(home: InviteScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('invite-share')));
    await tester.pump();
    await tester.pump();

    expect(share.origin, isNotNull);
    expect(share.origin!.width, greaterThan(0));
    expect(find.text('Sharing failed. Use Copy.'), findsOneWidget);
    expect(find.byKey(const Key('invite-copy')), findsOneWidget);
  });

  testWidgets('an open invite expires on the clock and hides share', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 16, 8, 42));
    final invites = FakeInviteRepository()
      ..invite = SquadInvite(
        code: 'CODE2345',
        expiresAt: DateTime.utc(2026, 11, 16, 8, 43),
        squadId: 'squad',
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inviteRepositoryProvider.overrideWithValue(invites),
          squadClockProvider.overrideWithValue(clock),
          localOffsetProvider.overrideWithValue(const Duration(hours: -6)),
          availabilityTickProvider.overrideWithValue(
            const Duration(seconds: 1),
          ),
        ],
        child: const MaterialApp(home: InviteScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('CODE2345'), findsOneWidget);
    expect(find.text('Expires Mon Nov 16, 2:43 AM'), findsOneWidget);
    expect(find.byKey(const Key('invite-copy')), findsOneWidget);
    expect(find.byKey(const Key('invite-share')), findsOneWidget);
    expect(find.byKey(const Key('invite-expired')), findsNothing);

    clock.set(DateTime.utc(2026, 11, 16, 8, 43));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Make a new code'), findsOneWidget);
    expect(find.byKey(const Key('invite-copy')), findsNothing);
    expect(find.byKey(const Key('invite-share')), findsNothing);
  });

  testWidgets('a missing invite backend does not show a code', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inviteRepositoryProvider.overrideWithValue(
            FakeInviteRepository(notEnabled: true),
          ),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const MaterialApp(home: InviteScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('invite-disabled')), findsOneWidget);
    expect(find.byKey(const Key('invite-code')), findsNothing);
  });

  testWidgets('joining with a code opens the chat, and a bad code stays put', (
    tester,
  ) async {
    final squads = FakeSquadRepository(startEmpty: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLinkProvider.overrideWithValue(AppLink.live),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              signedIn: const AuthUser(
                id: 'spencer',
                email: 'spencer@example.com',
              ),
            ),
          ),
          squadRepositoryProvider.overrideWithValue(squads),
          inviteRepositoryProvider.overrideWithValue(
            FakeInviteRepository(squads: squads),
          ),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('join-with-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-code-field')), 'NOPE');
    await tester.tap(find.byKey(const Key('join-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('That code is not valid. Nothing was joined.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('composer')), findsNothing);

    const messages = {
      'EXPIRED2':
          'That code has expired. Ask for a new one. Nothing was joined.',
      'FULL2345': 'That squad is full. Nothing was joined.',
      'MEMBER22': 'You are already in a squad. Nothing was changed.',
      'OWNS2345':
          'You own a squad that still has other people. Nothing was changed.',
    };
    for (final entry in messages.entries) {
      await tester.enterText(
        find.byKey(const Key('join-code-field')),
        entry.key,
      );
      await tester.tap(find.byKey(const Key('join-submit')));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byKey(const Key('composer')), findsNothing);
    }

    await tester.enterText(
      find.byKey(const Key('join-code-field')),
      'good-2345',
    );
    await tester.tap(find.byKey(const Key('join-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('squad-home')), findsOneWidget);
    expect(find.byKey(const Key('join-dialog')), findsNothing);
  });

  testWidgets('a squad that was not opened stays on the setup screen', (
    tester,
  ) async {
    final squads = FakeSquadRepository(startEmpty: true)..failCreate = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLinkProvider.overrideWithValue(AppLink.live),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              signedIn: const AuthUser(
                id: 'spencer',
                email: 'spencer@example.com',
              ),
            ),
          ),
          squadRepositoryProvider.overrideWithValue(squads),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-squad')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The squad was not opened. Nothing is on screen until the server returns it.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('composer')), findsNothing);

    squads.failCreate = false;
    await tester.tap(find.byKey(const Key('start-squad')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('squad-home')), findsOneWidget);
  });
}

class _ThrowingShare implements CodeShare {
  Rect? origin;

  @override
  Future<void> copy(String text) async {}

  @override
  Future<void> share(String text, {Rect? origin}) async {
    this.origin = origin;
    throw PlatformException(
      code: 'error',
      message: 'sharePositionOrigin: argument must be set, {{0, 0}, {0, 0}}',
    );
  }
}
