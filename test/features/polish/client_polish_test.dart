import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/domain/availability_board.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/availability/domain/who_can_play.dart';
import 'package:squadsync/features/chat/data/fake_chat_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';

void main() {
  test('ages stay short and clocks stay clocks', () {
    final at = DateTime.utc(2026, 11, 10, 21);
    expect(formatRelative(at, at), 'just now');
    expect(formatRelative(at, at.add(const Duration(minutes: 2))), '2m ago');
    expect(formatRelative(at, at.add(const Duration(hours: 3))), '3h ago');
    expect(formatLocalClock(at, Duration.zero), '9:00 PM');
  });

  test('a check-in says when it was set without dropping the clock', () {
    final now = DateTime.utc(2026, 11, 8, 20);
    final who = WhoCanPlay.group(
      board: AvailabilityBoard.compose(
        members: const [spencer],
        rows: [
          StoredCheckIn(
            userId: spencer.id,
            squadId: 'squad',
            kind: CheckInKind.availableNow,
            checkedAt: now.subtract(const Duration(minutes: 2)),
            until: now.add(const Duration(minutes: 50)),
          ),
        ],
        squadId: 'squad',
        clock: now,
      ),
      members: const [spencer],
    );
    expect(
      whoStatusLine(
        who.playingNow.single,
        localOffset: Duration.zero,
        now: now,
      ),
      'until 8:50 PM · Call of Duty · checked in, not detected · set 2m ago',
    );
    expect(
      whoSpokenLine(
        who.playingNow.single,
        localOffset: Duration.zero,
        now: now,
      ),
      'Spencer, playing Call of Duty, until 8:50 PM, set 2m ago',
    );
  });

  testWidgets('a cold start shimmers, then shows the squad', (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final gate = Completer<void>();
    final chats = FakeChatRepository()..holdNewest = gate.future;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatRepositoryProvider.overrideWithValue(chats)],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-loading')), findsOneWidget);
    expect(find.bySemanticsLabel('Loading the squad'), findsOneWidget);
    expect(find.bySemanticsLabel('Alex · Halo'), findsNothing);
    expect(tester.takeException(), isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-loading')), findsNothing);
    expect(find.byKey(const Key('squad-home')), findsOneWidget);
    final page = find
        .descendant(
          of: find.byKey(const Key('home-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('member-strip')),
      200,
      scrollable: page,
    );
    expect(find.byKey(const Key('member-strip')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('member-row'))).height, 112);
  });
}
