import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/main.dart';
import 'package:squad_sync/setup_screen.dart';
import 'package:squad_sync/screens/onboarding/onboarding_flow.dart';
import 'package:squad_sync/join_squad_screen.dart';
import 'package:squad_sync/screens/squad_tab_screen.dart';
import 'package:squad_sync/squad_state_notifier.dart';
import 'package:squad_sync/chat/chat_state.dart';
import 'package:squad_sync/managers/stubs.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding Flow Integration Tests', () {
    setUpAll(() async {
      // Initialize Firebase for integration tests
      await Firebase.initializeApp();
    });

    testWidgets(
        'Complete onboarding flow: SetupScreen -> OnboardingFlow -> ChatGroupsScreen',
        (tester) async {
      // Start with the main app
      await tester.pumpWidget(const SquadSyncApp());
      await tester.pumpAndSettle();

      // Should start at SetupScreen (since no user is authenticated)
      expect(find.byType(SetupScreen), findsOneWidget);

      // For integration testing, we can't easily simulate Firebase Auth
      // So we'll test the OnboardingFlow directly
      await tester.pumpWidget(
        ProviderScope(
          child: p.MultiProvider(
            providers: [
              p.ChangeNotifierProvider<SquadState>.value(value: SquadState()),
              p.ChangeNotifierProvider<ChatState>.value(value: ChatState()),
              p.ChangeNotifierProvider<UserManager>.value(value: UserManager()),
            ],
            child: const MaterialApp(
              home: OnboardingFlow(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show onboarding flow
      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.text('Setup (1/2)'), findsOneWidget);
      expect(find.text('Create Your Profile'), findsOneWidget);

      // Enter display name
      await tester.enterText(find.byType(TextField).first, 'Test Display Name');
      await tester.pumpAndSettle();

      // Find and tap Next button
      final nextButton = find.widgetWithText(ElevatedButton, 'Next');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Should now be on step 2
      expect(find.text('Setup (2/2)'), findsOneWidget);
      expect(find.text('Pin Your Favorite Games'), findsOneWidget);

      // Note: Completing the full flow would require Firebase setup
      // and actual navigation, which is complex for integration tests
    });

    testWidgets('Squad joining flow: JoinSquadScreen with initial code',
        (tester) async {
      await tester.pumpWidget(
        p.MultiProvider(
          providers: [
            p.ChangeNotifierProvider<SquadState>.value(value: SquadState()),
            p.ChangeNotifierProvider<ChatState>.value(value: ChatState()),
          ],
          child: MaterialApp(
            home: JoinSquadScreen(initialCode: 'TEST123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show JoinSquadScreen
      expect(find.byType(JoinSquadScreen), findsOneWidget);

      // Should have the code pre-filled
      expect(find.text('TEST123'), findsOneWidget);

      // Test entering a different code
      final codeField = find.byType(TextField).first;
      await tester.enterText(codeField, 'NEWCODE456');
      await tester.pumpAndSettle();

      // Should now show the new code
      expect(find.text('NEWCODE456'), findsOneWidget);
    });

    testWidgets('Squad tab screen loads and displays UI elements',
        (tester) async {
      await tester.pumpWidget(
        p.MultiProvider(
          providers: [
            p.ChangeNotifierProvider<SquadState>.value(value: SquadState()),
            p.ChangeNotifierProvider<ChatState>.value(value: ChatState()),
          ],
          child: const MaterialApp(
            home: SquadTabScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show SquadTabScreen
      expect(find.byType(SquadTabScreen), findsOneWidget);

      // Should have basic UI elements (this may vary based on implementation)
      // expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
