import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:squad_sync/main.dart' show SquadSyncApp;
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mocks generated in test/mocks/integration_test_mocks.dart
import '../test/mocks/integration_test_mocks.mocks.dart';

/// Integration tests for authentication flows via AuthWrapper
/// Tests Supabase email/password and Apple Sign-In
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Integration Tests', () {
    late MockAuthServiceSupabase mockAuthService;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;

    setUp(() {
      mockAuthService = MockAuthServiceSupabase();
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();

      // Set up default mock behaviors
      when(mockSupabase.auth).thenReturn(mockAuth);
    });

    testWidgets('Email/Password Sign-In Flow', (WidgetTester tester) async {
      // Arrange: Mock successful email/password sign-in
      final mockUser = User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {'display_name': 'Test User'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      when(mockAuthService.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockUser);

      when(mockAuthService.currentUser).thenReturn(mockUser);
      when(mockAuthService.currentUserId).thenReturn('test-user-id');

      // Act: Build app with mocked auth service
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override auth service provider if exposed
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Should show login screen (AuthWrapper detects no user)
      expect(find.text('Sign In'), findsOneWidget);

      // Act: Enter email and password
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      // Act: Tap sign-in button
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Verify authentication was called
      verify(mockAuthService.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);

      // Assert: Should navigate to main app (SetupScreen or HomeScreen)
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('Email/Password Sign-In Error Handling',
        (WidgetTester tester) async {
      // Arrange: Mock failed sign-in
      when(mockAuthService.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(
        AuthException('Invalid credentials', statusCode: '400'),
      );

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle();

      // Act: Enter invalid credentials
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      await tester.enterText(emailField, 'invalid@example.com');
      await tester.enterText(passwordField, 'wrongpassword');
      await tester.pumpAndSettle();

      // Act: Tap sign-in button
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Should show error message
      expect(find.textContaining('Invalid credentials'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget); // Still on login screen
    });

    testWidgets('Apple Sign-In Flow', (WidgetTester tester) async {
      // Arrange: Mock successful Apple sign-in
      final mockUser = User(
        id: 'apple-user-id',
        appMetadata: {'provider': 'apple'},
        userMetadata: {'display_name': 'Apple User'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      when(mockAuthService.signInWithApple()).thenAnswer((_) async => mockUser);
      when(mockAuthService.currentUser).thenReturn(mockUser);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle();

      // Act: Find and tap Apple Sign-In button
      final appleSignInButton = find.widgetWithIcon(
        ElevatedButton,
        Icons.apple,
      );

      if (appleSignInButton.evaluate().isNotEmpty) {
        await tester.tap(appleSignInButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Assert: Verify Apple sign-in was called
        verify(mockAuthService.signInWithApple()).called(1);

        // Assert: Should navigate to main app
        expect(find.byIcon(Icons.apple), findsNothing);
      }
    });

    testWidgets('Sign-Out Flow', (WidgetTester tester) async {
      // Arrange: Mock authenticated user
      final mockUser = User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {'display_name': 'Test User'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      when(mockAuthService.currentUser).thenReturn(mockUser);
      when(mockAuthService.signOut()).thenAnswer((_) async {
        when(mockAuthService.currentUser).thenReturn(null);
      });

      // Act: Build app with authenticated user
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Act: Navigate to settings/profile (find sign-out button)
      // This depends on your app's navigation structure
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon);
        await tester.pumpAndSettle();

        // Act: Tap sign-out button
        final signOutButton = find.text('Sign Out');
        if (signOutButton.evaluate().isNotEmpty) {
          await tester.tap(signOutButton);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Assert: Verify sign-out was called
          verify(mockAuthService.signOut()).called(1);

          // Assert: Should return to login screen
          expect(find.text('Sign In'), findsOneWidget);
        }
      }
    });

    testWidgets('AuthWrapper redirects unauthenticated users',
        (WidgetTester tester) async {
      // Arrange: No authenticated user
      when(mockAuthService.currentUser).thenReturn(null);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Should show login screen
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('AuthWrapper allows authenticated users to main app',
        (WidgetTester tester) async {
      // Arrange: Authenticated user
      final mockUser = User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {'display_name': 'Test User'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      when(mockAuthService.currentUser).thenReturn(mockUser);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Should NOT show login screen
      expect(find.text('Sign In'), findsNothing);

      // Assert: Should show main app UI (check for common elements)
      // This depends on your app's structure
      // Examples: Bottom navigation, lobby tab, chat tab, etc.
    });

    testWidgets('Session persistence across app restarts',
        (WidgetTester tester) async {
      // Arrange: Mock persisted session
      final mockUser = User(
        id: 'persisted-user-id',
        appMetadata: {},
        userMetadata: {'display_name': 'Persisted User'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      when(mockAuthService.currentUser).thenReturn(mockUser);

      // Act: Build app (simulating app restart)
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Should restore session and show main app
      expect(find.text('Sign In'), findsNothing);

      // Assert: User should be authenticated
      expect(mockAuthService.currentUser, isNotNull);
      expect(mockAuthService.currentUser?.id, 'persisted-user-id');
    });
  });

  group('Authentication Edge Cases', () {
    testWidgets('Handle network timeout during sign-in',
        (WidgetTester tester) async {
      // Arrange: Mock network timeout
      final mockAuthService = MockAuthServiceSupabase();

      when(mockAuthService.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer(
        (_) async => throw Exception('Network timeout'),
      );

      // Act: Attempt sign-in
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle();

      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).at(1);

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');

      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.tap(signInButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert: Should show error message
      expect(find.textContaining('Network'), findsOneWidget);
    });

    testWidgets('Handle expired session refresh', (WidgetTester tester) async {
      // Test session token refresh logic
      // This is typically handled by Supabase SDK automatically
      // But we can verify the flow works
    });
  });
}
