import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cod_squad_app/chat/alert_card_widget.dart';
import 'package:cod_squad_app/squad_state.dart';

void main() {
  group('AlertCardWidget', () {
    testWidgets('renders correctly with basic data',
        (WidgetTester tester) async {
      final squadState = SquadState();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SquadState>.value(value: squadState),
            ],
            child: AlertCardWidget(
              gameName: 'TestGame',
              hostName: 'TestHost',
              maxSpots: 4,
              chatGroupId: 'testChatId',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check if the widget builds without errors
      expect(find.byType(AlertCardWidget), findsOneWidget);
    });

    testWidgets('displays correct text', (WidgetTester tester) async {
      final squadState = SquadState();
      // Mock some data
      squadState.gameSquadSpots['TestGame'] = [null, 'user1'];

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SquadState>.value(value: squadState),
            ],
            child: AlertCardWidget(
              gameName: 'TestGame',
              hostName: 'TestHost',
              maxSpots: 4,
              chatGroupId: 'testChatId',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("TestHost's TestGame: 2/4 spots left – Join?"),
          findsOneWidget);
    });
  });
}
