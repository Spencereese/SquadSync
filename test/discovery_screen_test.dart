import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/screens/discovery_screen.dart';
import 'package:squad_sync/services/firestore_service_refactored.dart';
import 'package:squad_sync/services/grok_service.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Generate mocks
// @GenerateMocks([
//   FirestoreService,
//   GrokService,
//   NotificationManager,
//   SQLiteHelper,
//   FirebaseFirestore,
// ])
// import 'discovery_screen_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirestoreService mockFirestoreService;
  late MockGrokService mockGrokService;
  late MockNotificationManager mockNotificationManager;
  late MockSQLiteHelper mockSQLiteHelper;
  late MockFirebaseFirestore mockFirebaseFirestore;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    mockGrokService = MockGrokService();
    mockNotificationManager = MockNotificationManager();
    mockSQLiteHelper = MockSQLiteHelper();
    mockFirebaseFirestore = MockFirebaseFirestore();
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        firestoreServiceRefactoredProvider
            .overrideWithValue(mockFirestoreService),
        grokServiceProvider.overrideWithValue(mockGrokService),
        notificationManagerProvider.overrideWithValue(mockNotificationManager),
        sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: child,
      ),
    );
  }

  group('DiscoveryScreen Widget Tests', () {
    testWidgets('renders correctly with initial state', (tester) async {
      await tester.pumpWidget(createTestWidget(const DiscoveryScreen()));

      // Check that the screen renders
      expect(find.text('Discover Groups'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows loading state when fetching groups', (tester) async {
      // Mock the notifier to be in loading state
      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = const FirestoreState(isLoading: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays groups when data is loaded', (tester) async {
      final testGroups = [
        {
          'id': '1',
          'name': 'Warzone Squad',
          'memberCount': 10,
          'gameName': 'Warzone',
          'description': 'Looking for teammates',
          'imageUrl': null,
        },
        {
          'id': '2',
          'name': 'COD Mobile Team',
          'memberCount': 5,
          'gameName': 'COD Mobile',
          'description': null,
          'imageUrl': null,
        },
      ];

      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = FirestoreState(
        suggestedGroups: AsyncValue.data(testGroups),
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      // Check that groups are displayed
      expect(find.text('Warzone Squad'), findsOneWidget);
      expect(find.text('COD Mobile Team'), findsOneWidget);
      expect(find.text('10 members'), findsOneWidget);
      expect(find.text('5 members'), findsOneWidget);
      expect(find.text('Warzone'), findsOneWidget);
      expect(find.text('COD Mobile'), findsOneWidget);
    });

    testWidgets('shows error UI when loading fails', (tester) async {
      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = FirestoreState(
        suggestedGroups:
            AsyncValue.error(Exception('Network error'), StackTrace.current),
        isLoading: false,
        error: 'Network error',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      // Should show error message
      expect(find.text('Failed to load groups'), findsOneWidget);
      expect(find.text('Network error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button reloads data on error', (tester) async {
      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = FirestoreState(
        suggestedGroups:
            AsyncValue.error(Exception('Network error'), StackTrace.current),
        isLoading: false,
        error: 'Network error',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Verify that loadSuggestedGroups was called
      verify(mockNotifier.loadSuggestedGroups(any)).called(1);
    });

    testWidgets('search functionality triggers with debouncing',
        (tester) async {
      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      // Enter search text
      await tester.enterText(find.byType(TextField), 'warzone');
      await tester.pump();

      // Wait for debounce timer (300ms)
      await tester.pump(const Duration(milliseconds: 350));

      // Verify search was triggered
      verify(mockNotifier.loadSuggestedGroups(any)).called(1);
    });

    testWidgets('infinite scroll loads more data', (tester) async {
      final testGroups = List.generate(
        20,
        (i) => {
          'id': '$i',
          'name': 'Group $i',
          'memberCount': 10,
          'gameName': 'Warzone',
          'description': null,
          'imageUrl': null,
        },
      );

      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = FirestoreState(
        suggestedGroups: AsyncValue.data(testGroups),
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      // Scroll to bottom to trigger pagination
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Group 19'), // Last item
        500.0,
        scrollable: scrollable,
      );

      await tester.pump();

      // Verify loadNextPage was called
      verify(mockNotifier.loadNextPage()).called(1);
    });

    testWidgets('join group functionality works', (tester) async {
      final testGroups = [
        {
          'id': '1',
          'name': 'Test Group',
          'memberCount': 5,
          'gameName': 'Warzone',
          'description': null,
          'imageUrl': null,
        },
      ];

      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = FirestoreState(
        suggestedGroups: AsyncValue.data(testGroups),
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      // Tap join button
      await tester.tap(find.text('Join'));
      await tester.pump();

      // Should show loading state on button
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('empty state shows when no groups found', (tester) async {
      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = const FirestoreState(
        suggestedGroups: AsyncValue.data([]),
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      // Should show empty state message
      expect(find.text('No groups found'), findsOneWidget);
      expect(find.text('Try adjusting your search or check back later'),
          findsOneWidget);
    });

    testWidgets('performance test - renders within 200ms', (tester) async {
      final largeGroupList = List.generate(
        100,
        (i) => {
          'id': '$i',
          'name': 'Performance Group $i',
          'memberCount': 10 + (i % 50),
          'gameName': i % 2 == 0 ? 'Warzone' : 'COD Mobile',
          'description': 'This is a performance test group with index $i',
          'imageUrl': null,
        },
      );

      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = FirestoreState(
        suggestedGroups: AsyncValue.data(largeGroupList),
        isLoading: false,
      );

      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      stopwatch.stop();

      // Performance check - should render within 200ms
      expect(stopwatch.elapsedMilliseconds, lessThan(200));

      // Verify all groups are rendered
      expect(find.text('Performance Group 0'), findsOneWidget);
      expect(find.text('Performance Group 99'), findsOneWidget);
    });

    testWidgets('handles rapid scroll events efficiently', (tester) async {
      final testGroups = List.generate(
        50,
        (i) => {
          'id': '$i',
          'name': 'Scroll Test Group $i',
          'memberCount': 10,
          'gameName': 'Warzone',
          'description': null,
          'imageUrl': null,
        },
      );

      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = FirestoreState(
        suggestedGroups: AsyncValue.data(testGroups),
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      final stopwatch = Stopwatch()..start();

      // Perform rapid scroll operations
      final scrollable = find.byType(Scrollable).first;
      for (int i = 0; i < 10; i++) {
        await tester.scrollUntilVisible(
          find.text('Scroll Test Group ${40 + i}'),
          100.0,
          scrollable: scrollable,
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      stopwatch.stop();

      // Should handle rapid scrolling efficiently
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    testWidgets('accessibility - semantic labels are present', (tester) async {
      final testGroups = [
        {
          'id': '1',
          'name': 'Accessible Group',
          'memberCount': 5,
          'gameName': 'Warzone',
          'description': 'Test description',
          'imageUrl': null,
        },
      ];

      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = FirestoreState(
        suggestedGroups: AsyncValue.data(testGroups),
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump();

      // Check for accessibility labels
      expect(find.bySemanticsLabel('Search groups'), findsOneWidget);
      expect(find.bySemanticsLabel('Join Accessible Group'), findsOneWidget);
    });

    testWidgets('handles memory pressure with large datasets', (tester) async {
      // Test with a very large dataset to simulate memory pressure
      final hugeGroupList = List.generate(
        1000,
        (i) => {
          'id': '$i',
          'name': 'Memory Test Group $i',
          'memberCount': i % 100,
          'gameName': 'Warzone',
          'description': 'Memory pressure test group $i',
          'imageUrl': null,
        },
      );

      final mockNotifier = SuggestedGroupsNotifier(mockFirestoreService);
      mockNotifier.state = FirestoreState(
        suggestedGroups: AsyncValue.data(hugeGroupList),
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestedGroupsNotifierProvider.overrideWithValue(mockNotifier),
            firestoreServiceRefactoredProvider
                .overrideWithValue(mockFirestoreService),
            grokServiceProvider.overrideWithValue(mockGrokService),
            notificationManagerProvider
                .overrideWithValue(mockNotificationManager),
            sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
          ],
          child: const MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: DiscoveryScreen(),
          ),
        ),
      );

      // This should not crash or cause memory issues
      await tester.pump();

      // Verify basic functionality still works
      expect(find.text('Memory Test Group 0'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
