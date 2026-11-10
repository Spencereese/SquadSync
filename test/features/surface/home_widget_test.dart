import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/domain/availability_board.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/availability/domain/who_can_play.dart';
import 'package:squadsync/features/chat/ui/squad_chat_screen.dart';
import 'package:squadsync/features/spot/domain/spot_call.dart';
import 'package:squadsync/features/surface/data/fake_squad_surface.dart';
import 'package:squadsync/features/surface/data/platform_squad_surface.dart';
import 'package:squadsync/features/surface/domain/squad_surface.dart';
import 'package:squadsync/features/surface/ui/surface_sync.dart';
import 'package:squadsync/core/app.dart';

void main() {
  final clock = DateTime.utc(2026, 11, 10, 21);

  HomeWidgetSnapshot snapshot({SpotCall? spot, bool spotMissing = false}) {
    final who = WhoCanPlay(
      squadSize: 8,
      rows: [
        WhoRow(
          person: const PersonAvailability(
            userId: 'alex',
            displayName: 'Alex',
            effect: AvailabilityEffect.availableNow,
            checkIn: null,
          ),
          game: 'Halo',
          group: WhoGroup.available,
        ),
      ],
    );
    return homeWidgetSnapshot(
      who: who,
      availabilityMissing: false,
      spot: spot,
      spotMissing: spotMissing,
      clock: clock,
    );
  }

  SpotCall openSpot({
    String callerId = 'spencer',
    DateTime? joinUntil,
    DateTime? lockedAt,
    List<SpotRsvp>? rsvps,
  }) {
    return SpotCall(
      id: 'spot-1',
      squadId: 'squad',
      callerId: callerId,
      game: 'Halo',
      startsAt: clock,
      calledAt: clock,
      joinUntil: joinUntil ?? clock.add(const Duration(minutes: 5)),
      lockedAt: lockedAt,
      rsvps:
          rsvps ??
          const [
            SpotRsvp(
              userId: 'spencer',
              response: SpotAnswer.rsvpIn,
              starter: true,
            ),
            SpotRsvp(
              userId: 'alex',
              response: SpotAnswer.rsvpOut,
              starter: false,
            ),
          ],
    );
  }

  test('widget payload is who is on and the open spot', () {
    final spot = openSpot();
    final shot = snapshot(spot: spot);
    expect(shot.whoSummary, '1 of 8 available');
    expect(shot.whoNames, 'Alex');
    expect(shot.spotLine, contains('to join Halo'));
    expect(shot.spotLine, contains('Called just now'));
    expect(shot.honesty, homeWidgetHonesty);
    expect(shot.honesty, contains('does not stay live in the background'));
    expect(shot.fields['who_summary'], shot.whoSummary);
    expect(shot.fields['spot_line'], shot.spotLine);
  });

  test('an empty board and a missing spot stay honest', () {
    final shot = homeWidgetSnapshot(
      who: WhoCanPlay(squadSize: 1, rows: const []),
      availabilityMissing: false,
      spot: null,
      spotMissing: false,
      clock: clock,
    );
    expect(shot.whoSummary, '0 of 8 available');
    expect(shot.whoNames, 'Nobody is checked in.');
    expect(shot.spotLine, 'No spot called.');

    final missing = homeWidgetSnapshot(
      who: null,
      availabilityMissing: true,
      spot: null,
      spotMissing: true,
      clock: clock,
    );
    expect(missing.whoSummary, 'Availability is not enabled yet.');
    expect(missing.spotLine, 'Spots are not enabled yet.');
  });

  test('caller activity starts only for the caller of an open spot', () {
    final spot = openSpot();
    final activity = callerActivityFor(
      call: spot,
      meId: 'spencer',
      clock: clock,
    );
    expect(activity, isNotNull);
    expect(activity!.game, 'Halo');
    expect(activity.inCount, 1);
    expect(activity.outCount, 1);
    expect(activity.fields['joinUntilMillis'], isNotEmpty);
    expect(callerActivityFor(call: spot, meId: 'alex', clock: clock), isNull);
    expect(otherMemberLiveActivityHook, contains('Parked'));
  });

  test('lock, end, cancel, and expiry dismiss the caller activity', () {
    final open = openSpot();
    expect(
      callerActivityFor(
        call: open,
        meId: 'spencer',
        clock: clock.add(const Duration(minutes: 5)),
      ),
      isNull,
    );
    expect(
      callerActivityFor(
        call: openSpot(lockedAt: clock),
        meId: 'spencer',
        clock: clock,
      ),
      isNull,
    );
    expect(
      callerActivityFor(call: null, meId: 'spencer', clock: clock),
      isNull,
    );
  });

  test(
    'android skips live activities and a missing plugin does not throw',
    () async {
      final android = PlatformSquadSurface(ios: false);
      await android.upsertCallerActivity(
        CallerActivity(
          callId: 'spot-1',
          game: 'Halo',
          joinUntil: clock.add(const Duration(minutes: 5)),
          inCount: 1,
          outCount: 0,
        ),
      );
      expect(android.skippedLiveActivity, isTrue);
      await android.endCallerActivity();

      final ios = PlatformSquadSurface(ios: true);
      await ios.publish(snapshot());
      expect(ios.lastProblem, isNotNull);
      await ios.upsertCallerActivity(
        CallerActivity(
          callId: 'spot-1',
          game: 'Halo',
          joinUntil: clock.add(const Duration(minutes: 5)),
          inCount: 1,
          outCount: 0,
        ),
      );
      expect(ios.lastProblem, isNotNull);
    },
  );

  testWidgets('the home note fits a phone at double text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          squadSurfaceProvider.overrideWithValue(FakeSquadSurface()),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    final page = find
        .descendant(
          of: find.byKey(const Key('home-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-widget-note')),
      200,
      scrollable: page,
    );
    expect(find.text(homeWidgetHonesty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calling a spot updates the widget and the caller activity', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 10, 21));
    final surface = FakeSquadSurface();
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          squadSurfaceProvider.overrideWithValue(surface),
          squadClockProvider.overrideWithValue(clock),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      surface.snapshots.any(
        (shot) =>
            shot.whoSummary == '0 of 8 available' &&
            shot.whoNames == 'Nobody is checked in.' &&
            shot.spotLine == 'No spot called.',
      ),
      isTrue,
    );

    final page = find
        .descendant(
          of: find.byKey(const Key('home-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('spot-call')),
      200,
      scrollable: page,
    );
    await tester.tap(find.byKey(const Key('spot-call')));
    await tester.pumpAndSettle();
    expect(surface.activity, isNotNull);
    expect(surface.activity!.game, 'Halo');
    expect(surface.activity!.inCount, 1);
    expect(surface.snapshots.last.spotLine, contains('to join Halo'));

    await tester.scrollUntilVisible(
      find.byKey(const Key('spot-out')),
      200,
      scrollable: page,
    );
    await tester.tap(find.byKey(const Key('spot-out')));
    await tester.pumpAndSettle();
    expect(surface.activity!.outCount, 1);
    expect(surface.activity!.inCount, 0);

    await tester.tap(find.byKey(const Key('spot-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spot-cancel-confirm')));
    await tester.pumpAndSettle();
    expect(surface.activity, isNull);
    expect(surface.ended, 1);
    expect(find.text('No spot called.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('spot-call')),
      200,
      scrollable: page,
    );
    await tester.tap(find.byKey(const Key('spot-call')));
    await tester.pumpAndSettle();
    expect(surface.activity, isNotNull);
    final startedBeforeExpiry = surface.started;
    clock.advance(const Duration(minutes: 5));
    await ProviderScope.containerOf(
      tester.element(find.byType(SquadChatScreen)),
    ).read(surfaceSyncProvider).publish(meId: 'spencer');
    await tester.pumpAndSettle();
    expect(surface.activity, isNull);
    expect(surface.ended, 2);
    expect(surface.started, startedBeforeExpiry);

    await tester.tap(find.byKey(const Key('spot-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spot-cancel-confirm')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('spot-call')),
      200,
      scrollable: page,
    );
    await tester.tap(find.byKey(const Key('spot-call')));
    await tester.pumpAndSettle();
    expect(surface.activity, isNotNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('spot-lock')),
      200,
      scrollable: page,
    );
    await tester.tap(find.byKey(const Key('spot-lock')));
    await tester.pumpAndSettle();
    expect(surface.activity, isNull);
    expect(find.textContaining('Locked.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('spot-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spot-end-confirm')));
    await tester.pumpAndSettle();
    expect(surface.activity, isNull);
    expect(find.text('No spot called.'), findsOneWidget);
    expect(find.byKey(const Key('squad-home')), findsOneWidget);
  });

  testWidgets('a widget failure leaves home, chat, and spots up', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          squadSurfaceProvider.overrideWithValue(_ThrowingSurface()),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('squad-home')), findsOneWidget);
    expect(find.byKey(const Key('who-summary')), findsOneWidget);
    expect(find.byKey(const Key('spot-status')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('view-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ThrowingSurface implements SquadSurface {
  @override
  Future<void> publish(HomeWidgetSnapshot snapshot) async {
    throw StateError('widget plugin missing');
  }

  @override
  Future<void> upsertCallerActivity(CallerActivity activity) async {
    throw StateError('live activity missing');
  }

  @override
  Future<void> endCallerActivity() async {
    throw StateError('live activity missing');
  }
}
