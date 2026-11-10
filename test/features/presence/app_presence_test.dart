import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/presence/data/fake_app_presence.dart';
import 'package:squadsync/features/presence/domain/app_presence.dart';
import 'package:squadsync/features/presence/ui/app_presence_controller.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/ui/member_strip.dart';

const alex = Member(id: 'alex', displayName: 'Alex', defaultGame: 'Halo');

void main() {
  test('the presence topic is not the typing channel', () {
    expect(appPresenceTopic('squad'), 'sq8-presence-squad');
    expect(appPresenceTopic('squad').contains('typing'), isFalse);
    expect(
      presenceUserIds(const [
        {'user_id': 'alex'},
        {'user_id': ''},
        {'name': 'nope'},
      ]),
      {'alex'},
    );
  });

  test('opening tracks you and leaving drops the channel', () async {
    final source = FakeAppPresence();
    final container = ProviderContainer(
      overrides: [appPresenceSourceProvider.overrideWithValue(source)],
    );
    addTearDown(container.dispose);
    final presence = container.read(appPresenceControllerProvider.notifier);

    await presence.open(squadId: 'squad', userId: spencer.id);
    await Future<void>.delayed(Duration.zero);

    expect(source.topics, ['sq8-presence-squad']);
    expect(source.trackedUserId, spencer.id);
    expect(
      container.read(appPresenceControllerProvider).isHere(spencer.id),
      isTrue,
    );

    await presence.open(squadId: 'squad', userId: spencer.id);
    expect(source.watches, 1);

    await presence.leave();
    expect(source.trackedUserId, isNull);
    expect(container.read(appPresenceControllerProvider).available, isFalse);

    await presence.open(squadId: 'squad', userId: spencer.id);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(appPresenceControllerProvider).isHere(spencer.id),
      isTrue,
    );
  });

  test('a presence error hides the dots and does not throw', () async {
    final source = FakeAppPresence();
    final container = ProviderContainer(
      overrides: [appPresenceSourceProvider.overrideWithValue(source)],
    );
    addTearDown(container.dispose);
    await container
        .read(appPresenceControllerProvider.notifier)
        .open(squadId: 'squad', userId: spencer.id);
    await Future<void>.delayed(Duration.zero);
    source.loseRealtime();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appPresenceControllerProvider).available, isFalse);
    expect(
      container.read(appPresenceControllerProvider).isHere(spencer.id),
      isFalse,
    );
  });

  testWidgets('dots come and go on a 402 by 874 phone, including 2x text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = FakeAppPresence();
    final container = ProviderContainer(
      overrides: [appPresenceSourceProvider.overrideWithValue(source)],
    );
    addTearDown(container.dispose);
    await container
        .read(appPresenceControllerProvider.notifier)
        .open(squadId: 'squad', userId: spencer.id);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: MemberStrip(members: [spencer, alex])),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('in-app-spencer')), findsOneWidget);
    expect(find.byKey(const Key('away-alex')), findsOneWidget);
    expect(find.text('Spencer · Call of Duty'), findsOneWidget);
    expect(find.textContaining('via Steam'), findsNothing);
    expect(find.textContaining('Playing'), findsNothing);
    expect(tester.takeException(), isNull);

    source.show(alex.id);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('in-app-alex')), findsOneWidget);

    source.hide(alex.id);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('in-app-alex')), findsNothing);
    expect(find.byKey(const Key('away-alex')), findsOneWidget);

    final handle = tester.ensureSemantics();
    final labels = _labels(tester);
    expect(
      labels.where((label) => label == 'Spencer, Call of Duty. in the app'),
      hasLength(1),
    );
    expect(
      labels.where((label) => label == 'Alex, Halo. not in the app'),
      hasLength(1),
    );
    handle.dispose();

    source.loseRealtime();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('in-app-spencer')), findsNothing);
    expect(find.byKey(const Key('away-alex')), findsNothing);
    expect(find.text('Spencer · Call of Duty'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('member-row'))).height, 112);
    expect(tester.takeException(), isNull);
  });
}

List<String> _labels(WidgetTester tester) {
  final root = tester
      .binding
      .renderViews
      .first
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
  final labels = <String>[];
  void walk(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(root);
  return labels;
}
