import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:squad_sync/screens/onboarding/onboarding_flow.dart';
import 'package:squad_sync/join_squad_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding Flow Integration Tests', () {
    testWidgets('Onboarding flow basic UI test', (tester) async {
      // Test the basic UI without complex state management
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingFlow(),
        ),
      );

      // Wait for initial load - this may fail due to Firebase dependencies
      // but let's see what happens
      await tester.pumpAndSettle();

      // Check if the onboarding flow is displayed
      expect(find.text('Create Your Profile'), findsOneWidget);
    });

    testWidgets('Join squad screen basic UI test', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JoinSquadScreen(initialCode: 'TEST123'),
        ),
      );

      await tester.pumpAndSettle();

      // Check if the join screen is displayed
      expect(find.byType(JoinSquadScreen), findsOneWidget);
    });
  });
}
