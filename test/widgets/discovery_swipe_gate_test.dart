import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/screens/discovery_swipe_screen.dart';
import 'package:squad_sync/services/discovery_swipe_gate.dart';
import 'package:squad_sync/widgets/discovery_swipe_gate.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(home: child),
    );
  }

  testWidgets('both-missing gate shows empty copy, not the swipe deck',
      (tester) async {
    await tester.pumpWidget(
      wrap(const DiscoverySwipeGatePanel(gate: DiscoverySwipeGate.closed)),
    );

    expect(find.byKey(kDiscoverySwipeGatePanelKey), findsOneWidget);
    expect(find.byKey(kDiscoverySwipeNeedBothKey), findsOneWidget);
    expect(find.text(kDiscoverySwipeGateTitle), findsOneWidget);
    expect(find.text(kDiscoverySwipeNeedBothCopy), findsOneWidget);
    expect(find.byKey(kDiscoverySwipeSurfaceKey), findsNothing);
    expect(find.text('DISCOVER SQUADS'), findsNothing);
  });

  testWidgets('need-fill gate names looking-for-fill', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DiscoverySwipeGatePanel(
          gate: DiscoverySwipeGate(
            lookingForFill: false,
            hasSquadVouch: true,
          ),
        ),
      ),
    );

    expect(find.byKey(kDiscoverySwipeNeedFillKey), findsOneWidget);
    expect(find.text(kDiscoverySwipeNeedFillCopy), findsOneWidget);
    expect(find.byKey(kDiscoverySwipeSurfaceKey), findsNothing);
  });

  testWidgets('need-vouch gate names squad vouch', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DiscoverySwipeGatePanel(
          gate: DiscoverySwipeGate(
            lookingForFill: true,
            hasSquadVouch: false,
          ),
        ),
      ),
    );

    expect(find.byKey(kDiscoverySwipeNeedVouchKey), findsOneWidget);
    expect(find.text(kDiscoverySwipeNeedVouchCopy), findsOneWidget);
    expect(find.byKey(kDiscoverySwipeSurfaceKey), findsNothing);
  });

  testWidgets('DiscoverySwipeScreen stays gated without fill + vouch',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const DiscoverySwipeScreen(gateOverride: DiscoverySwipeGate.closed),
      ),
    );

    expect(find.byKey(kDiscoverySwipeGatePanelKey), findsOneWidget);
    expect(find.byKey(kDiscoverySwipeNeedBothKey), findsOneWidget);
    expect(find.text(kDiscoverySwipeNeedBothCopy), findsOneWidget);
    expect(find.byKey(kDiscoverySwipeSurfaceKey), findsNothing);
    expect(find.text('JOIN'), findsNothing);
    expect(find.text('PASS'), findsNothing);
  });

  testWidgets('DiscoverySwipeScreen hides swipe without looking-for-fill',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const DiscoverySwipeScreen(
          gateOverride: DiscoverySwipeGate(
            lookingForFill: false,
            hasSquadVouch: true,
          ),
        ),
      ),
    );

    expect(find.byKey(kDiscoverySwipeNeedFillKey), findsOneWidget);
    expect(find.text(kDiscoverySwipeNeedFillCopy), findsOneWidget);
    expect(find.byKey(kDiscoverySwipeSurfaceKey), findsNothing);
    expect(find.text('JOIN'), findsNothing);
  });

  testWidgets('DiscoverySwipeScreen hides swipe without squad vouch',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const DiscoverySwipeScreen(
          gateOverride: DiscoverySwipeGate(
            lookingForFill: true,
            hasSquadVouch: false,
          ),
        ),
      ),
    );

    expect(find.byKey(kDiscoverySwipeNeedVouchKey), findsOneWidget);
    expect(find.text(kDiscoverySwipeNeedVouchCopy), findsOneWidget);
    expect(find.byKey(kDiscoverySwipeSurfaceKey), findsNothing);
    expect(find.text('JOIN'), findsNothing);
  });

  testWidgets('entry button is fill swipe, not a public Tinder launch',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        DiscoverySwipeEntryButton(onPressed: () => tapped = true),
      ),
    );

    expect(find.byKey(kDiscoverySwipeEntryKey), findsOneWidget);
    expect(find.text('Fill swipe'), findsOneWidget);
    expect(find.text('DISCOVER SQUADS'), findsNothing);
    await tester.tap(find.byKey(kDiscoverySwipeEntryKey));
    expect(tapped, isTrue);
  });
}
