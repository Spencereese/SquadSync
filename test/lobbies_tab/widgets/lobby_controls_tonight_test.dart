import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/screens/components/chat_info_actions.dart';

void main() {
  testWidgets(
      'lobby Tonight block groups I am on / LFG / Invite; Voice under More',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TonightActionsBlock(
                children: tonightStripChildren(
                  onNow: const Text("I'm on now"),
                  lookingForSquad: const Text('Looking for Squad'),
                  invite: const Text('Invite'),
                ),
              ),
              MoreActionsBlock(
                children: [
                  if (slotForTonightAction(kMoreVoiceAction) ==
                      TonightStripSlot.more)
                    const Text('Voice'),
                  if (slotForTonightAction(kDeadSearchAction) != null)
                    const Text('Search'),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('tonight-actions')), findsOneWidget);
    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text("I'm on now"), findsOneWidget);
    expect(find.text('Looking for Squad'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Voice'), findsNothing);
    expect(find.text('Search'), findsNothing);

    await tester.tap(find.byKey(const Key('more-actions-toggle')));
    await tester.pump();

    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Search'), findsNothing);
  });
}
