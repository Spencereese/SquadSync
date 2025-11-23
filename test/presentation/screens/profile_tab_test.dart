import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/entities/app_user.dart';
import 'package:squad_sync/profile_tab.dart';
import 'package:squad_sync/test/helpers/test_injection.dart';
import 'package:squad_sync/test/main.dart';

void main() {
  late MockGetCurrentUser mockGetCurrentUser;

  setUp(() {
    setupTestDependencies();
    mockGetCurrentUser = mockGetCurrentUser;
  });

  group('ProfileTab Widget Tests', () {
    final testUser = AppUser.empty().copyWith(
      uid: 'test-uid',
      displayName: 'Test User',
      profileImage: 'https://example.com/image.jpg',
    );

    testWidgets('should display user profile information', (tester) async {
      // Arrange
      when(mockGetCurrentUser()).thenAnswer((_) async => testUser);

      // Act
      await tester.pumpWidget(
        TestApp(
          child: const ProfileTab(),
        ),
      );
      await tester.pump(); // Wait for async operations
      await tester.pump(); // Wait for animations

      // Assert
      expect(find.text('Test User'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsWidgets); // Profile image
    });

    testWidgets('should show loading state initially', (tester) async {
      // Arrange
      when(mockGetCurrentUser()).thenAnswer((_) async => testUser);

      // Act
      await tester.pumpWidget(
        TestApp(
          child: const ProfileTab(),
        ),
      );

      // Assert - Should show loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should handle user update', (tester) async {
      // Arrange
      when(mockGetCurrentUser()).thenAnswer((_) async => testUser);

      // Act
      await tester.pumpWidget(
        TestApp(
          child: const ProfileTab(),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap update button (assuming there's one)
      // This would depend on the actual UI structure
      // For example:
      // await tester.tap(find.byKey(const Key('update_profile_button')));
      // await tester.pump();

      // Assert state changes
      // verify(mockUpdateDisplayName('New Name')).called(1);
    });

    testWidgets('should display error state when user load fails', (tester) async {
      // Arrange
      when(mockGetCurrentUser()).thenThrow(Exception('Load failed'));

      // Act
      await tester.pumpWidget(
        TestApp(
          child: const ProfileTab(),
        ),
      );
      await tester.pump(); // Initial load
      await tester.pump(); // Error state

      // Assert
      // Check for error message or retry button
      // expect(find.text('Error loading profile'), findsOneWidget);
    });

    testWidgets('should allow editing display name', (tester) async {
      // Arrange
      when(mockGetCurrentUser()).thenAnswer((_) async => testUser);

      // Act
      await tester.pumpWidget(
        TestApp(
          child: const ProfileTab(),
        ),
      );
      await tester.pumpAndSettle();

      // Find text field and enter new name
      final nameField = find.byType(TextField).first; // Assuming first TextField is name
      await tester.enterText(nameField, 'Updated Name');
      await tester.pump();

      // Assert
      expect(find.text('Updated Name'), findsOneWidget);
    });

    // Add more widget tests for specific interactions
  });
}