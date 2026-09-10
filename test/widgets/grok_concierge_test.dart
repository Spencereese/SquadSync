import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/grok_concierge.dart';
import 'package:squad_sync/services/grok_concierge_machine.dart';
import 'package:squad_sync/widgets/grok_concierge.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  testWidgets('three command buttons, no free-chat field', (tester) async {
    await tester.pumpWidget(
      wrap(
        GrokConciergeBlock(
          onWhosFree: () {},
          onSummarize: () {},
          onInvite: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('grok-concierge')), findsOneWidget);
    expect(find.byKey(const Key('grok-concierge-whos-free')), findsOneWidget);
    expect(find.byKey(const Key('grok-concierge-summarize')), findsOneWidget);
    expect(find.byKey(const Key('grok-concierge-invite')), findsOneWidget);
    expect(find.text(kGrokConciergeWhosFreeLabel), findsOneWidget);
    expect(find.text(kGrokConciergeSummarizeLabel), findsOneWidget);
    expect(find.text(kGrokConciergeInviteLabel), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('tapping a command shows the grok result, still no chat field',
      (tester) async {
    final runner = GrokConciergeRunner(
      spend: GrokSpendTracker(),
      caller: (message, {context, recentMessages, command}) async {
        return 'Sam is free tonight.';
      },
    );
    await tester.pumpWidget(
      wrap(
        GrokConciergeSection(
          runner: runner,
          contextOverride: GrokConciergeContext(
            now: DateTime.utc(2026, 9, 5, 21),
            members: const [
              GrokConciergeMember(uid: 'a', label: 'Sam', isOn: true),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('grok-concierge-whos-free')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('grok-concierge-result')), findsOneWidget);
    expect(find.text('Sam is free tonight.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('budget exceeded disables the three commands', (tester) async {
    await tester.pumpWidget(
      wrap(
        GrokConciergeBlock(
          budgetExceeded: true,
          onWhosFree: () {},
          onSummarize: () {},
          onInvite: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('grok-concierge-budget')), findsOneWidget);
    final whosFree = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('grok-concierge-whos-free')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(whosFree.onPressed, isNull);
  });
}
