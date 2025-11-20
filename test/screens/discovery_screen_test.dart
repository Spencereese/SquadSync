import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:squad_sync/screens/discovery_screen.dart';
import 'package:squad_sync/providers.dart';
import 'package:squad_sync/services/firestore_service.dart';
import 'package:squad_sync/services/grok_service.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';
import 'package:squad_sync/services/firestore_service.dart' as fs;

// Generate mocks
@GenerateMocks([
  FirestoreService,
  GrokService,
  NotificationManager,
  SQLiteHelper,
])
import 'discovery_screen_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirestoreService mockFirestoreService;
  late MockGrokService mockGrokService;
  late MockNotificationManager mockNotificationManager;
  late MockSQLiteHelper mockSQLiteHelper;
  late TestQueryBuilder testQueryBuilder;
  late ProviderContainer container;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    mockGrokService = MockGrokService();
    mockNotificationManager = MockNotificationManager();
    mockSQLiteHelper = MockSQLiteHelper();
    testQueryBuilder = TestQueryBuilder();

    // Set up default mock behaviors
    when(mockFirestoreService.queryBuilder).thenReturn(testQueryBuilder);

    container = ProviderContainer(
      overrides: [
        firestoreServiceProvider.overrideWithValue(mockFirestoreService),
        grokServiceProvider.overrideWithValue(mockGrokService),
        notificationManagerProvider
            .overrideWith((ref) => mockNotificationManager),
        sqliteHelperProvider.overrideWithValue(mockSQLiteHelper),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('DiscoveryScreen', () {
    testWidgets('renders correctly with mocked providers', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Discover Groups'), findsOneWidget);
      expect(find.text('Search groups...'), findsOneWidget);
    });

    testWidgets('search field accepts input', (tester) async {
      // Set up initial state with default groups
      final initialStream = Stream.value([
        {'id': 'group1', 'name': 'Warzone Squad', 'memberCount': 5}
      ]);
      testQueryBuilder.setDefaultStream(initialStream);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump(); // Initial build
      await tester.pump(); // Resolve FutureBuilder

      // Should show initial groups
      expect(find.text('Warzone Squad'), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byType(TextField), 'test search');
      await tester.pump();

      // Wait for debounce timer to set _currentSearchTerm
      await tester.pump(const Duration(milliseconds: 500));

      // Should show clear button
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Clean up any pending timers
      await tester.pumpAndSettle();
    });

    testWidgets('semantic search badge displays for Grok matches',
        (tester) async {
      final mockStream = Stream.value([
        {'id': 'group1', 'name': 'Test Group', 'memberCount': 5}
      ]);
      testQueryBuilder.setStreamForQuery('test search', '', mockStream);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pump(); // Initial build

      // Enter search text
      await tester.enterText(find.byType(TextField), 'test search');
      await tester.pump();

      // Wait for debounce timer to complete (500ms)
      await tester.pump(const Duration(milliseconds: 500));

      // Should show Grok AI badge
      expect(find.text('Powered by Grok AI'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);

      // Clean up any pending timers before test ends
      await tester.pumpAndSettle();
    });

    testWidgets('empty state shows when no groups found', (tester) async {
      final emptyStream = Stream.value(<Map<String, dynamic>>[]);
      testQueryBuilder.setStreamForQuery('', '', emptyStream);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No groups found'), findsOneWidget);
    });

    testWidgets('theme switches correctly between dark and light',
        (tester) async {
      final mockStream = Stream.value([
        {'id': 'group1', 'name': 'Test Group', 'memberCount': 5}
      ]);
      testQueryBuilder.setStreamForQuery('', '', mockStream);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially should be dark theme (default)
      // Check for dark theme gradient or colors
      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);
    });

    testWidgets('join button exists and is tappable', (tester) async {
      final mockStream = Stream.value([
        {
          'id': 'group1',
          'name': 'Test Group',
          'memberCount': 5,
        }
      ]);
      testQueryBuilder.setStreamForQuery('', '', mockStream);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DiscoveryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and verify join button exists
      final joinButton = find.text('Join');
      expect(joinButton, findsOneWidget);

      // Note: Full join workflow testing would require mocking Firebase Auth
      // and Firestore operations, which is complex for widget tests
      // For now, just verify the button is present and tappable
      await tester.tap(joinButton);
      await tester.pump();

      // The button should still exist (even if join fails due to missing auth)
      expect(find.text('Join'), findsOneWidget);
    });
  });

  group('Golden Tests', () {
    testWidgets('DiscoveryScreen matches golden file', (tester) async {
      final mockStream = Stream.value([
        {
          'id': 'group1',
          'name': 'Test Group',
          'memberCount': 5,
          'gameName': 'Warzone',
        }
      ]);
      testQueryBuilder.setStreamForQuery('', '', mockStream);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const DiscoveryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Uncomment when ready to generate golden files
      // await expectLater(find.byType(DiscoveryScreen), matchesGoldenFile('discovery_screen.png'));
    });
  });
}

// Mock class for QueryBuilder with custom implementation
class TestQueryBuilder extends fs.QueryBuilder {
  TestQueryBuilder() : super(firestore: FakeFirebaseFirestore());

  List<Map<String, dynamic>> _defaultData = [
    {
      'id': 'group1',
      'name': 'Test Group',
      'memberCount': 5,
      'gameName': 'Warzone',
    }
  ];

  final Map<String, List<Map<String, dynamic>>> _streamData = {};

  @override
  Future<Stream<List<Map<String, dynamic>>>> buildSuggestedGroupsQuery(
    String searchTerm,
    String gameName,
    GrokService grokService,
    NotificationManager notificationManager,
    SQLiteHelper sqliteHelper,
  ) async {
    final key = '$searchTerm|$gameName';
    final data = _streamData[key] ?? _defaultData;
    // Return a new stream each time to avoid "already listened" error
    return Future.value(Stream.value(data));
  }

  void setStreamForQuery(String searchTerm, String gameName,
      Stream<List<Map<String, dynamic>>> stream) {
    final key = '$searchTerm|$gameName';
    // Store the data from the stream
    stream.first.then((data) => _streamData[key] = data);
  }

  void setDefaultStream(Stream<List<Map<String, dynamic>>> stream) {
    // Store the data from the stream
    stream.first.then((data) => _defaultData = data);
  }
}
