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
    expect(find.text('Mute this squad'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mute-this-squad-switch')));
    await tester.pump();
    expect(muted, isTrue);
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
    expect(find.text('Quiet Hours'), findsOneWidget);
    expect(find.byKey(const Key('quiet-hours-start')), findsNothing);
    expect(find.byKey(const Key('quiet-hours-end')), findsNothing);
  });

  testWidgets('quiet hours shows window and start/end when on', (tester) async {
    var enabled = true;
    await tester.pumpWidget(
      wrap(
        QuietHoursSettings(
          enabled: enabled,
          startMinutes: 22 * 60,
          endMinutes: 8 * 60,
          onEnabledChanged: (value) => enabled = value,
          onStartChanged: (_) {},
          onEndChanged: (_) {},
        ),
      ),
    );

    expect(find.text('No sends 22:00 – 08:00'), findsOneWidget);
    expect(find.byKey(const Key('quiet-hours-start')), findsOneWidget);
    expect(find.byKey(const Key('quiet-hours-end')), findsOneWidget);
    expect(find.text('22:00'), findsWidgets);
    expect(find.text('08:00'), findsOneWidget);
  });
}
