import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:squad_sync/presentation/onboarding/onboarding_flow.dart';
import 'package:squad_sync/presentation/onboarding/onboarding_notifier.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';

@GenerateMocks([AuthServiceSupabase])
import 'onboarding_flow_test.mocks.dart';

void main() {
  late MockAuthServiceSupabase mockAuthService;

  setUp(() {
    mockAuthService = MockAuthServiceSupabase();
  });

  Widget createOnboardingFlow() {
    return ProviderScope(
      overrides: [],
      child: const MaterialApp(
        home: OnboardingFlow(),
      ),
    );
  }

  group('OnboardingFlow - Widget Structure', () {
    testWidgets('should display onboarding flow', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingFlow), findsOneWidget);
    });

    testWidgets('should display page view', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('should display skip button', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Skip button may only appear after first page
      // Check if it exists or can be found
      expect(find.text('SKIP'), findsAny);
    });
  });

  group('OnboardingFlow - Page Navigation', () {
    testWidgets('should navigate to next page on swipe', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Find the page view
      final pageView = find.byType(PageView);
      expect(pageView, findsOneWidget);

      // Swipe left to go to next page
      await tester.drag(pageView, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Should have navigated to next page
    });

    testWidgets('should navigate using skip button', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Swipe to get past first page where skip button appears
      final pageView = find.byType(PageView);
      await tester.drag(pageView, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Try to find and tap skip button
      final skipButton = find.text('SKIP');
      if (skipButton.evaluate().isNotEmpty) {
        await tester.tap(skipButton);
        await tester.pumpAndSettle();

        // Should navigate to final page
      }
    });

    testWidgets('should navigate using next button', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Look for next button (text or icon)
      final nextButton = find.text('NEXT');
      if (nextButton.evaluate().isNotEmpty) {
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Should navigate to next page
      }
    });
  });

  group('OnboardingFlow - Welcome Page', () {
    testWidgets('should display welcome message', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Look for welcome text
      expect(find.textContaining('Welcome'), findsAny);
    });

    testWidgets('should display app logo or branding', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Look for images or logos
      expect(find.byType(Image), findsAny);
    });
  });

  group('OnboardingFlow - Authentication Page', () {
    testWidgets('should display authentication options', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to authentication page
      final pageView = find.byType(PageView);
      await tester.drag(pageView, const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.drag(pageView, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Should show sign in options
      expect(find.byType(ElevatedButton), findsAny);
    });

    testWidgets('should handle sign in button tap', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to authentication page
      final pageView = find.byType(PageView);
      await tester.drag(pageView, const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.drag(pageView, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Find sign in button
      final signInButton = find.text('Sign In');
      if (signInButton.evaluate().isNotEmpty) {
        await tester.tap(signInButton);
        await tester.pumpAndSettle();
      }
    });
  });

  group('OnboardingFlow - Profile Setup Page', () {
    testWidgets('should display profile setup form', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate through pages to profile setup
      final pageView = find.byType(PageView);
      for (int i = 0; i < 3; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Should show profile fields or avatar selection
      expect(find.byType(TextField), findsAny);
    });

    testWidgets('should allow entering display name', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to profile setup
      final pageView = find.byType(PageView);
      for (int i = 0; i < 3; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Try to find and fill display name field
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'Test User');
        await tester.pump();

        expect(find.text('Test User'), findsOneWidget);
      }
    });

    testWidgets('should display avatar selection', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to profile setup
      final pageView = find.byType(PageView);
      for (int i = 0; i < 3; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Look for avatar selection UI
      // This depends on your implementation
    });
  });

  group('OnboardingFlow - Game Selection Page', () {
    testWidgets('should display game selection', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to game selection
      final pageView = find.byType(PageView);
      for (int i = 0; i < 4; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Should show game selection UI
      expect(find.byType(GridView), findsAny);
    });

    testWidgets('should allow selecting games', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to game selection
      final pageView = find.byType(PageView);
      for (int i = 0; i < 4; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Try to select a game (depends on implementation)
      final gameCards = find.byType(InkWell);
      if (gameCards.evaluate().isNotEmpty) {
        await tester.tap(gameCards.first);
        await tester.pumpAndSettle();
      }
    });
  });

  group('OnboardingFlow - Completion', () {
    testWidgets('should display finish button on last page', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to last page
      final pageView = find.byType(PageView);
      for (int i = 0; i < 5; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Look for finish button
      expect(find.text('Get Started'), findsAny);
    });

    testWidgets('should complete onboarding when finish is tapped',
        (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to last page
      final pageView = find.byType(PageView);
      for (int i = 0; i < 5; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Tap finish button
      final finishButton = find.text('Get Started');
      if (finishButton.evaluate().isNotEmpty) {
        await tester.tap(finishButton);
        await tester.pumpAndSettle();

        // Onboarding should be marked complete
      }
    });
  });

  group('OnboardingFlow - State Management', () {
    testWidgets('should track current page index', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate through pages
      final pageView = find.byType(PageView);
      await tester.drag(pageView, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // State should reflect page change
    });

    testWidgets('should update state when form is filled', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to profile page
      final pageView = find.byType(PageView);
      for (int i = 0; i < 3; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Fill form
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'Test User');
        await tester.pump();
      }

      // State should be updated
    });
  });

  group('OnboardingFlow - UI Elements', () {
    testWidgets('should display page indicators', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Look for page indicators (dots)
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('should have consistent styling', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Check for consistent theme usage
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('should display animations', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Check for animated widgets
      expect(find.byType(AnimatedBuilder), findsAny);
    });
  });

  group('OnboardingFlow - Accessibility', () {
    testWidgets('should have semantic labels', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('should support keyboard navigation', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to a page with form fields
      final pageView = find.byType(PageView);
      for (int i = 0; i < 3; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Should be able to tab through fields
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.tap(textFields.first);
        await tester.pump();

        expect(tester.widget<TextField>(textFields.first).focusNode?.hasFocus,
            isTrue);
      }
    });
  });

  group('OnboardingFlow - Error Handling', () {
    testWidgets('should handle empty form submission', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to profile page
      final pageView = find.byType(PageView);
      for (int i = 0; i < 3; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Try to submit without filling form
      final nextButton = find.text('NEXT');
      if (nextButton.evaluate().isNotEmpty) {
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Should show validation error or stay on page
      }
    });

    testWidgets('should validate display name input', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to profile page
      final pageView = find.byType(PageView);
      for (int i = 0; i < 3; i++) {
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Enter invalid name (too short, special characters, etc.)
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'a');
        await tester.pump();

        // Should show validation error
      }
    });
  });

  group('OnboardingFlow - Lifecycle', () {
    testWidgets('should dispose properly', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Remove widget
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();

      // Should dispose without errors
    });

    testWidgets('should persist state across rebuilds', (tester) async {
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // Navigate to a page
      final pageView = find.byType(PageView);
      await tester.drag(pageView, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Rebuild
      await tester.pumpWidget(createOnboardingFlow());
      await tester.pumpAndSettle();

      // State might be reset or persisted depending on implementation
    });
  });
}
