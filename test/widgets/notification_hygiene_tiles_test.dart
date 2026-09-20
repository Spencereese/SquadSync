import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/notification_hygiene.dart';
import 'package:squad_sync/widgets/notification_hygiene_tiles.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent),
      ),
      home: Scaffold(body: child),
    );
  }

  testWidgets('Mute this squad switch reports on', (tester) async {
    var muted = false;
    await tester.pumpWidget(
      wrap(
        MuteThisSquadTile(
          muted: muted,
          onChanged: (value) => muted = value,
        ),
      ),
    );

    expect(find.byKey(const Key('mute-this-squad')), findsOneWidget);
    expect(find.text(MuteThisSquadTile.titleLabel), findsOneWidget);
    await tester.tap(find.byKey(const Key('mute-this-squad-switch')));
    await tester.pump();
    expect(muted, isTrue);
  });

  testWidgets('unmuted mute tile shows empty-state copy', (tester) async {
    await tester.pumpWidget(
      wrap(
        MuteThisSquadTile(
          muted: false,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('mute-this-squad-empty')), findsOneWidget);
    expect(find.text(MuteThisSquadTile.emptyLabel), findsOneWidget);
    expect(find.byKey(const Key('mute-this-squad-on')), findsNothing);
    expect(find.text(MuteThisSquadTile.mutedLabel), findsNothing);
  });

  testWidgets('muted mute tile shows on-state copy', (tester) async {
    await tester.pumpWidget(
      wrap(
        MuteThisSquadTile(
          muted: true,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('mute-this-squad-on')), findsOneWidget);
    expect(find.text(MuteThisSquadTile.mutedLabel), findsOneWidget);
    expect(find.byKey(const Key('mute-this-squad-empty')), findsNothing);
  });

  testWidgets('quiet hours hides start/end until enabled', (tester) async {
    await tester.pumpWidget(
      wrap(
        QuietHoursSettings(
          enabled: false,
          startMinutes: NotificationHygiene.defaultStartMinutes,
          endMinutes: NotificationHygiene.defaultEndMinutes,
          onEnabledChanged: (_) {},
          onStartChanged: (_) {},
          onEndChanged: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('quiet-hours-settings')), findsOneWidget);
    expect(find.text(QuietHoursSettings.titleLabel), findsOneWidget);
    expect(find.byKey(const Key('quiet-hours-start')), findsNothing);
    expect(find.byKey(const Key('quiet-hours-end')), findsNothing);
  });

  testWidgets('quiet hours empty state shows default window', (tester) async {
    await tester.pumpWidget(
      wrap(
        QuietHoursSettings(
          enabled: false,
          startMinutes: NotificationHygiene.defaultStartMinutes,
          endMinutes: NotificationHygiene.defaultEndMinutes,
          onEnabledChanged: (_) {},
          onStartChanged: (_) {},
          onEndChanged: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('quiet-hours-empty')), findsOneWidget);
    expect(
      find.text('Off — pause all notification sends 22:00 – 08:00 overnight'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('quiet-hours-on')), findsNothing);
  });

  testWidgets('quiet hours shows window and start/end when on', (tester) async {
    var enabled = true;
    await tester.pumpWidget(
      wrap(
        QuietHoursSettings(
          enabled: enabled,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 12),
          onEnabledChanged: (value) => enabled = value,
          onStartChanged: (_) {},
          onEndChanged: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('quiet-hours-on')), findsOneWidget);
    expect(
      find.text('Pausing all notification sends 22:00 – 08:00 overnight'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('quiet-hours-start')), findsOneWidget);
    expect(find.byKey(const Key('quiet-hours-end')), findsOneWidget);
    expect(find.text('22:00'), findsWidgets);
    expect(find.text('08:00'), findsOneWidget);
  });

  testWidgets('quiet hours settings entry is tappable', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      wrap(
        QuietHoursSettingsEntry(
          onOpen: () => opened = true,
        ),
      ),
    );

    expect(find.byKey(const Key('quiet-hours-settings-entry')), findsOneWidget);
    expect(find.text(QuietHoursSettingsEntry.titleLabel), findsOneWidget);
    expect(find.text(QuietHoursSettingsEntry.subtitleLabel), findsOneWidget);
    await tester.tap(find.byKey(const Key('quiet-hours-settings-entry')));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('settings header names quiet hours and mute', (tester) async {
    await tester.pumpWidget(
      wrap(const NotificationHygieneSettingsHeader()),
    );

    expect(find.byKey(const Key('notification-hygiene-entry')), findsOneWidget);
    expect(
      find.text(NotificationHygieneSettingsHeader.titleLabel),
      findsOneWidget,
    );
    expect(
      find.text(NotificationHygieneSettingsHeader.subtitleLabel),
      findsOneWidget,
    );
  });

  testWidgets('muted squads empty state points to squad info', (tester) async {
    await tester.pumpWidget(
      wrap(const MutedSquadsSettingsTile(mutedCount: 0)),
    );

    expect(find.byKey(const Key('muted-squads-empty')), findsOneWidget);
    expect(find.text(MutedSquadsSettingsTile.titleLabel), findsOneWidget);
    expect(find.text(MutedSquadsSettingsTile.emptyLabel), findsOneWidget);
    expect(find.byKey(const Key('muted-squads-count')), findsNothing);
  });

  testWidgets('muted squads count when some muted', (tester) async {
    await tester.pumpWidget(
      wrap(const MutedSquadsSettingsTile(mutedCount: 2)),
    );

    expect(find.byKey(const Key('muted-squads-count')), findsOneWidget);
    expect(find.text('2 muted squads. Unmute from that squad\'s info.'),
        findsOneWidget);
    expect(find.byKey(const Key('muted-squads-empty')), findsNothing);
  });

  testWidgets('quiet hours empty schedule shows copy and start/end',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        QuietHoursSettings(
          enabled: true,
          startMinutes: 12 * 60,
          endMinutes: 12 * 60,
          onEnabledChanged: (_) {},
          onStartChanged: (_) {},
          onEndChanged: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('quiet-hours-empty-schedule')), findsOneWidget);
    expect(find.text(kQuietHoursEmptyScheduleCopy), findsOneWidget);
    expect(find.text(kQuietHoursEmptyScheduleHint), findsOneWidget);
    expect(find.byKey(const Key('quiet-hours-start')), findsOneWidget);
    expect(find.byKey(const Key('quiet-hours-end')), findsOneWidget);
    expect(find.byKey(const Key('quiet-hours-on')), findsNothing);
  });

  testWidgets('quiet hours midnight wrap names overnight window',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        QuietHoursSettings(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 0,
          now: DateTime(2026, 1, 1, 12),
          onEnabledChanged: (_) {},
          onStartChanged: (_) {},
          onEndChanged: (_) {},
        ),
      ),
    );

    expect(
      find.text('Pausing all notification sends 22:00 – 00:00 overnight'),
      findsOneWidget,
    );
  });

  testWidgets('toggle off while window active shows off copy', (tester) async {
    var enabled = true;
    final now = DateTime(2026, 1, 1, 23, 15);

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return QuietHoursSettings(
              enabled: enabled,
              startMinutes: 22 * 60,
              endMinutes: 8 * 60,
              now: now,
              onEnabledChanged: (value) => setState(() => enabled = value),
              onStartChanged: (_) {},
              onEndChanged: (_) {},
            );
          },
        ),
      ),
    );

    expect(find.byKey(const Key('quiet-hours-active-now')), findsOneWidget);
    expect(
      find.text('Pausing now through 08:00. $kQuietHoursActiveNowHint'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('quiet-hours-toggle')));
    await tester.pump();

    expect(enabled, isFalse);
    expect(find.byKey(const Key('quiet-hours-empty')), findsOneWidget);
    expect(find.byKey(const Key('quiet-hours-active-now')), findsNothing);
    expect(find.byKey(const Key('quiet-hours-start')), findsNothing);
  });

  testWidgets('quiet hours error copy offers Retry and never a spinner',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        QuietHoursSettings(
          enabled: true,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          now: DateTime(2026, 1, 1, 12),
          error: 'offline',
          onRetry: () => retried = true,
          onEnabledChanged: (_) {},
          onStartChanged: (_) {},
          onEndChanged: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('quiet-hours-error')), findsOneWidget);
    expect(find.text(kQuietHoursErrorCopy), findsOneWidget);
    expect(find.text(kQuietHoursErrorHint), findsOneWidget);
    expect(find.byKey(const Key('quiet-hours-retry')), findsOneWidget);
    expect(find.text(kQuietHoursRetryLabel), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('quiet-hours-retry')));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('mute error copy offers Retry and never a spinner',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        MuteThisSquadTile(
          muted: true,
          error: 'denied',
          onRetry: () => retried = true,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('mute-this-squad-error')), findsOneWidget);
    expect(find.text(kMuteThisSquadErrorCopy), findsOneWidget);
    expect(find.text(kMuteThisSquadErrorHint), findsOneWidget);
    expect(find.byKey(const Key('mute-this-squad-retry')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('mute-this-squad-on')), findsNothing);

    await tester.tap(find.byKey(const Key('mute-this-squad-retry')));
    await tester.pump();
    expect(retried, isTrue);
  });
}
