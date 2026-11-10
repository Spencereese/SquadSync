import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/data/fake_availability_repository.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/availability/ui/who_can_play_panel.dart';
import 'package:squadsync/features/chat/ui/squad_chat_screen.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

const _phone = Size(402, 874);

void _expectOnScreen(WidgetTester tester, Finder finder) {
  expect(finder.hitTestable(), findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(_phone.height));
  expect(rect.right, lessThanOrEqualTo(_phone.width));
}

Future<void> _openPhone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [availabilityTickProvider.overrideWithValue(Duration.zero)],
      child: const SquadSyncApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the phone shows the count, status, and first section', (
    tester,
  ) async {
    await _openPhone(tester);

    _expectOnScreen(tester, find.byKey(const Key('who-summary')));
    _expectOnScreen(tester, find.byKey(const Key('status-available')));
    _expectOnScreen(tester, find.byKey(const Key('status-later')));
    _expectOnScreen(tester, find.byKey(const Key('status-cant')));
    expect(find.byKey(const Key('section-playing')), findsNothing);
    expect(find.text('Playing now'), findsNothing);
    _expectOnScreen(tester, find.byKey(const Key('section-available')));
    expect(find.text('0 of 8 available'), findsOneWidget);
    expect(find.byKey(const Key('who-empty')), findsOneWidget);
    expect(find.text('Nobody else yet'), findsNothing);
    expect(find.text('Maybe later 0 · Offline 1'), findsOneWidget);
  });

  testWidgets('double text still shows the count and status buttons', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openPhone(tester);

    _expectOnScreen(tester, find.byKey(const Key('who-summary')));
    _expectOnScreen(tester, find.byKey(const Key('status-available')));
    expect(tester.takeException(), isNull);

    final page = find
        .descendant(
          of: find.byKey(const Key('home-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('who-expand')),
      120,
      scrollable: page,
    );
    await tester.drag(page, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('who-expand')).hitTestable(at: Alignment.topCenter),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('who-panel')),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
  });

  testWidgets('a row and the count are each one semantics node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const alex = Member(
      id: 'alex',
      displayName: 'Alex',
      defaultGame: 'Call of Duty',
    );
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final home = Squad(
      id: 'squad',
      ownerId: spencer.id,
      members: const [spencer, alex],
    );
    final repo = FakeAvailabilityRepository(
      clock: clock,
      seed: [
        StoredCheckIn(
          userId: 'alex',
          squadId: 'squad',
          kind: CheckInKind.availableNow,
          checkedAt: clock.now(),
          until: DateTime.utc(2026, 11, 8, 22, 30),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          squadClockProvider.overrideWithValue(clock),
          localOffsetProvider.overrideWithValue(Duration.zero),
          availabilityTickProvider.overrideWithValue(Duration.zero),
          availabilityRepositoryProvider.overrideWithValue(repo),
          squadRepositoryProvider.overrideWithValue(
            FakeSquadRepository(seed: home),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: WhoCanPlayPanel(squad: home, meId: spencer.id),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final root = tester
        .binding
        .renderViews
        .first
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!;
    final nodes = <SemanticsNode>[];
    void walk(SemanticsNode node) {
      nodes.add(node);
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(root);
    expect(
      nodes
          .where(
            (node) =>
                node.label == 'Alex, playing Call of Duty, until 10:30 PM',
          )
          .length,
      1,
    );
    expect(nodes.where((node) => node.label.contains('Alex')).length, 1);
    expect(
      nodes.where((node) => node.label.contains('of 8 available')).length,
      1,
    );
    expect(
      nodes
          .where(
            (node) =>
                node.flagsCollection.isHeader && node.label == 'Playing now',
          )
          .length,
      1,
    );
    expect(
      nodes
          .where(
            (node) =>
                node.flagsCollection.isButton &&
                node.label.contains('Available'),
          )
          .length,
      1,
    );
    handle.dispose();
  });

  testWidgets('background then resume moves maybe later onto the board', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    const friend = Member(
      id: 'friend',
      displayName: 'Friend',
      defaultGame: 'Halo',
    );
    final repo = FakeAvailabilityRepository(
      clock: clock,
      seed: [
        StoredCheckIn(
          userId: 'friend',
          squadId: 'squad',
          kind: CheckInKind.availableLater,
          checkedAt: DateTime.utc(2026, 11, 8, 18),
          until: DateTime.utc(2026, 11, 8, 21),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          squadClockProvider.overrideWithValue(clock),
          localOffsetProvider.overrideWithValue(Duration.zero),
          availabilityTickProvider.overrideWithValue(
            const Duration(minutes: 5),
          ),
          availabilityRepositoryProvider.overrideWithValue(repo),
          squadRepositoryProvider.overrideWithValue(
            FakeSquadRepository(
              seed: Squad(
                id: 'squad',
                ownerId: spencer.id,
                members: const [spencer, friend],
              ),
            ),
          ),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('who-expand')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Maybe later from 9:00 PM'), findsOneWidget);
    expect(find.textContaining('Available since'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock.set(DateTime.utc(2026, 11, 8, 21));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Maybe later from 9:00 PM'), findsOneWidget);
    expect(find.textContaining('Available since'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('1 of 8 available'), findsOneWidget);
    expect(
      find.textContaining(
        'Friend · Available since 9:00 PM · Halo · checked in, not detected',
      ),
      findsOneWidget,
    );
    expect(repo.rows.single.kind, CheckInKind.availableLater);
  });

  testWidgets('chat fills the screen and the empty state is centered', (
    tester,
  ) async {
    await _openPhone(tester);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    final list = tester.getRect(find.byKey(const Key('message-list')));
    expect(list.height, greaterThanOrEqualTo(_phone.height * 0.6));
    final empty = tester.getRect(find.byKey(const Key('no-messages')));
    expect(find.byKey(const Key('no-messages')), findsOneWidget);
    expect((empty.center.dy - list.center.dy).abs(), lessThan(24));
    expect(find.byKey(const Key('composer')), findsOneWidget);
    expect(find.byKey(const Key('section-playing')), findsNothing);
  });

  testWidgets('the views switch and a thread open lands on Chat', (
    tester,
  ) async {
    await _openPhone(tester);
    expect(find.byKey(const Key('section-available')), findsOneWidget);
    expect(find.byKey(const Key('composer')), findsNothing);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer')), findsOneWidget);
    expect(find.byKey(const Key('section-playing')), findsNothing);

    await tester.tap(find.byKey(const Key('chat-who-summary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('section-available')), findsOneWidget);
    expect(find.byKey(const Key('composer')), findsNothing);

    final context = tester.element(find.byType(SquadSyncApp));
    ProviderScope.containerOf(context)
        .read(squadHomeViewProvider.notifier)
        .openThread();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-list')), findsOneWidget);
    expect(find.byKey(const Key('composer')), findsOneWidget);
    expect(find.byKey(const Key('section-playing')), findsNothing);
  });
}
