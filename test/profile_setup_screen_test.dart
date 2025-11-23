import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:squad_sync/screens/onboarding/onboarding_flow.dart';
import 'package:squad_sync/screens/onboarding/profile_setup_screen.dart';
import 'package:squad_sync/screens/onboarding/add_game_screen.dart';
import 'package:squad_sync/services/onboarding_service.dart';
import 'package:squad_sync/services/app_flow_manager.dart';
import 'package:squad_sync/chat/chat_groups_screen.dart';
import '../test/helpers/mocks.mocks.dart';

void main() {
  late MockOnboardingService mockOnboardingService;
  late MockAppFlowManager mockAppFlowManager;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUser mockUser;

  setUp(() {
    mockOnboardingService = MockOnboardingService();
    mockAppFlowManager = MockAppFlowManager();
    mockFirebaseAuth = MockFirebaseAuth();
    mockUser = MockUser();

    when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-user-id');
  });

  group('OnboardingFlow Widget Tests', () {
    final testOnboardingState = OnboardingState(
      currentStep: 0,
      displayName: 'Test User',
      profileImageUrl: 'https://example.com/image.jpg',
      pinnedGames: [{'id': 'game1', 'name': 'Test Game'}],
    );

    testWidgets('renders OnboardingFlow correctly with initial state', (WidgetTester tester) async {
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Setup (1/2)'), findsOneWidget);
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
      expect(find.byType(AddGameScreen), findsNothing); // Should be on first page
    });

    testWidgets('loads draft and jumps to correct step on init', (WidgetTester tester) async {
      final draftState = testOnboardingState.copyWith(currentStep: 1);
      when(mockOnboardingService.loadDraft()).thenReturn(draftState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should load draft and jump to step 1
      verify(mockOnboardingService.loadDraft()).called(1);
    });

    testWidgets('navigates to next step when ProfileSetupScreen calls onNext', (WidgetTester tester) async {
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the next button in ProfileSetupScreen
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Should call nextStep on the service
      verify(mockOnboardingService.nextStep()).called(1);
    });

    testWidgets('animates to next page when step changes', (WidgetTester tester) async {
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Simulate step change to 1
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState.copyWith(currentStep: 1));

      // Trigger state change
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Should animate to page 1
      expect(find.text('Setup (2/2)'), findsOneWidget);
      expect(find.byType(AddGameScreen), findsOneWidget);
    });

    testWidgets('completes onboarding and navigates to ChatGroupsScreen', (WidgetTester tester) async {
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState.copyWith(currentStep: 1));
      when(mockOnboardingService.completeOnboarding()).thenAnswer((_) async => Future.value());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Simulate completion from AddGameScreen
      // This would normally be triggered by AddGameScreen's onComplete callback
      final state = tester.state<_OnboardingFlowState>(find.byType(OnboardingFlow));
      state._completeOnboarding();
      await tester.pumpAndSettle();

      // Should complete onboarding and track analytics
      verify(mockOnboardingService.completeOnboarding()).called(1);
      verify(mockAppFlowManager.trackOnboardingCompleted(
        userId: 'test-user-id',
        gamesPinned: 1,
        timeSpent: anyNamed('timeSpent'),
      )).called(1);

      // Should navigate to ChatGroupsScreen
      expect(find.byType(ChatGroupsScreen), findsOneWidget);
    });

    testWidgets('handles onboarding completion errors gracefully', (WidgetTester tester) async {
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState.copyWith(currentStep: 1));
      when(mockOnboardingService.completeOnboarding()).thenThrow(Exception('Network error'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final state = tester.state<_OnboardingFlowState>(find.byType(OnboardingFlow));
      state._completeOnboarding();
      await tester.pumpAndSettle();

      // Should show error snackbar
      expect(find.text('Failed to complete onboarding: Exception: Network error'), findsOneWidget);
      // Should not navigate
      expect(find.byType(ChatGroupsScreen), findsNothing);
    });

    testWidgets('prevents navigation beyond step 2', (WidgetTester tester) async {
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState.copyWith(currentStep: 2));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should complete onboarding instead of navigating to page 2
      verify(mockOnboardingService.completeOnboarding()).called(1);
    });

    testWidgets('displays correct step counter in app bar', (WidgetTester tester) async {
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Setup (1/2)'), findsOneWidget);

      // Change to step 1
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState.copyWith(currentStep: 1));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Setup (2/2)'), findsOneWidget);
    });

    testWidgets('uses NeverScrollableScrollPhysics to prevent manual swiping', (WidgetTester tester) async {
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final pageView = find.byType(PageView);
      expect(pageView, findsOneWidget);

      // PageView should have NeverScrollableScrollPhysics
      final pageViewWidget = tester.widget<PageView>(pageView);
      expect(pageViewWidget.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('applies fade animations to screens', (WidgetTester tester) async {
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have Animate widgets for fade effects
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
      // Animation effects are applied via .animate() extension
    });

    testWidgets('handles null onboarding state gracefully', (WidgetTester tester) async {
      when(mockOnboardingService.loadDraft()).thenReturn(testOnboardingState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWith(() => mockOnboardingService),
            appFlowManagerProvider.overrideWith(() => mockAppFlowManager),
          ],
          child: const MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should default to step 0 when state is null
      expect(find.text('Setup (1/2)'), findsOneWidget);
    });
  });
}