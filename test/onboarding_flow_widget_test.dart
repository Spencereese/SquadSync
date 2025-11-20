import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:squad_sync/screens/onboarding/onboarding_flow.dart';
import 'package:squad_sync/join_squad_screen.dart';
import 'package:squad_sync/screens/squad_tab_screen.dart';

// Mock providers for testing
class MockSquadState with ChangeNotifier {
  String? selectedSquadId;
}

class MockChatState with ChangeNotifier {}

class MockUserManager with ChangeNotifier {}

class MockGameManager with ChangeNotifier {}

void main() {
  group('Onboarding Flow Widget Tests', () {
    testWidgets('OnboardingFlow renders first step', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: p.MultiProvider(
            providers: [
              p.ChangeNotifierProvider<MockSquadState>.value(
                  value: MockSquadState()),
              p.ChangeNotifierProvider<MockChatState>.value(
                  value: MockChatState()),
              p.ChangeNotifierProvider<MockUserManager>.value(
                  value: MockUserManager()),
              p.ChangeNotifierProvider<MockGameManager>.value(
                  value: MockGameManager()),
            ],
            child: const MaterialApp(
              home: OnboardingFlow(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that the onboarding flow is rendered
      expect(find.byType(OnboardingFlow), findsOneWidget);
      // Check for common UI elements that should be present
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('JoinSquadScreen renders with initial code input',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: p.MultiProvider(
            providers: [
              p.ChangeNotifierProvider<MockSquadState>.value(
                  value: MockSquadState()),
              p.ChangeNotifierProvider<MockChatState>.value(
                  value: MockChatState()),
              p.ChangeNotifierProvider<MockUserManager>.value(
                  value: MockUserManager()),
              p.ChangeNotifierProvider<MockGameManager>.value(
                  value: MockGameManager()),
            ],
            child: const MaterialApp(
              home: JoinSquadScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that the join squad screen is rendered
      expect(find.byType(JoinSquadScreen), findsOneWidget);
      // Check for text input field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('SquadTabScreen renders when squad is selected',
        (tester) async {
      final squadState = MockSquadState();
      squadState.selectedSquadId = 'test-squad-id';

      await tester.pumpWidget(
        ProviderScope(
          child: p.MultiProvider(
            providers: [
              p.ChangeNotifierProvider<MockSquadState>.value(value: squadState),
              p.ChangeNotifierProvider<MockChatState>.value(
                  value: MockChatState()),
              p.ChangeNotifierProvider<MockUserManager>.value(
                  value: MockUserManager()),
              p.ChangeNotifierProvider<MockGameManager>.value(
                  value: MockGameManager()),
            ],
            child: const MaterialApp(
              home: SquadTabScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that the squad tab screen is rendered
      expect(find.byType(SquadTabScreen), findsOneWidget);
    });
  });
}
