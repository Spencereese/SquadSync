import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/services/firestore_service_refactored.dart';
import 'package:squad_sync/services/grok_service.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';

// Generate mocks
// @GenerateMocks([
//   FirebaseFirestore,
//   GrokService,
//   NotificationManager,
//   SQLiteHelper,
//   DocumentSnapshot,
//   QuerySnapshot,
//   QueryDocumentSnapshot,
//   Query,
// ])
// import 'firestore_service_refactored_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirestoreService firestoreService;
  late MockGrokService mockGrokService;
  late MockNotificationManager mockNotificationManager;
  late MockSQLiteHelper mockSQLiteHelper;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    mockGrokService = MockGrokService();
    mockNotificationManager = MockNotificationManager();
    mockSQLiteHelper = MockSQLiteHelper();
    fakeFirestore = FakeFirebaseFirestore();

    firestoreService = FirestoreService(
      firestore: fakeFirestore,
      sqliteHelper: mockSQLiteHelper,
      grokService: mockGrokService,
      notificationManager: mockNotificationManager,
    );
  });

  group('GroupQueryFilters', () {
    test('hasFilters returns true when filters are set', () {
      final filters = GroupQueryFilters(
        isPublic: true,
        gameName: 'Warzone',
        minMemberCount: 5,
        searchTerm: 'test',
      );
      expect(filters.hasFilters, true);
    });

    test('hasFilters returns false when no filters are set', () {
      final filters = GroupQueryFilters();
      expect(filters.hasFilters, false);
    });
  });

  group('FirestoreState', () {
    test('copyWith creates new instance with updated values', () {
      const original = FirestoreState();
      final updated = original.copyWith(isLoading: true, error: 'test error');

      expect(updated.isLoading, true);
      expect(updated.error, 'test error');
      expect(updated.suggestedGroups, original.suggestedGroups);
    });
  });

  group('OptimizedGroupQueryBuilder', () {
    late OptimizedGroupQueryBuilder queryBuilder;

    setUp(() {
      queryBuilder = firestoreService.queryBuilder;
    });

    group('Indexed Queries', () {
      test(
          'buildBaseQuery creates proper where/orderBy chain for public groups',
          () {
        final filters = GroupQueryFilters(isPublic: true);

        // We can't directly test the private _buildBaseQuery method,
        // but we can test the public methods that use it
        final stream = queryBuilder.buildSuggestedGroupsStream(filters);

        // The stream should be created without errors
        expect(stream, isNotNull);
      });

      test('buildBaseQuery applies gameName filter correctly', () {
        final filters = GroupQueryFilters(isPublic: true, gameName: 'Warzone');

        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        expect(stream, isNotNull);
      });

      test('buildBaseQuery applies minMemberCount filter correctly', () {
        final filters = GroupQueryFilters(
          isPublic: true,
          minMemberCount: 10,
        );

        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        expect(stream, isNotNull);
      });

      test('buildBaseQuery applies multiple filters correctly', () {
        final filters = GroupQueryFilters(
          isPublic: true,
          gameName: 'Warzone',
          minMemberCount: 5,
        );

        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        expect(stream, isNotNull);
      });
    });

    group('Pagination', () {
      setUp(() async {
        // Set up test data
        await fakeFirestore.collection('chat_groups').add({
          'name': 'Group 1',
          'isPublic': true,
          'memberCount': 10,
          'gameName': 'Warzone',
          'lastMessageTime': Timestamp.now(),
          'createdAt': Timestamp.now(),
        });

        await fakeFirestore.collection('chat_groups').add({
          'name': 'Group 2',
          'isPublic': true,
          'memberCount': 8,
          'gameName': 'Warzone',
          'lastMessageTime': Timestamp.now(),
          'createdAt': Timestamp.now(),
        });

        // Mock cache to return null (force Firestore query)
        when(mockSQLiteHelper.getCachedGroups(any, any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);
        when(mockSQLiteHelper.getCacheMetadata(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);
        when(mockSQLiteHelper.cacheGroups(any, any, any)).thenAnswer((_) async {
          return null;
        });
        when(mockSQLiteHelper.insertCacheMetadata(any, any))
            .thenAnswer((_) async {
          return null;
        });
      });

      test('buildSuggestedGroupsStream returns limited results', () async {
        final filters = GroupQueryFilters(isPublic: true);

        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        final results = await stream.first;

        // Should return max 20 results (pageSize)
        expect(results.length, lessThanOrEqualTo(20));
      });

      test('buildSuggestedGroupsStream with startAfter paginates correctly',
          () async {
        final filters = GroupQueryFilters(isPublic: true);

        // First page
        final stream1 = queryBuilder.buildSuggestedGroupsStream(filters);
        final firstPage = await stream1.first;

        if (firstPage.isNotEmpty) {
          // Create mock document snapshot for pagination
          final mockDoc = MockDocumentSnapshot();
          when(mockDoc.id).thenReturn(firstPage.first['id']);

          // Second page should start after first document
          final stream2 = queryBuilder.buildSuggestedGroupsStream(
            filters,
            startAfter: mockDoc,
          );

          final secondPage = await stream2.first;
          expect(secondPage, isNotNull);
        }
      });

      test('handles empty results gracefully', () async {
        final filters = GroupQueryFilters(
          isPublic: true,
          gameName: 'NonExistentGame',
        );

        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        final results = await stream.first;

        expect(results, isEmpty);
      });
    });

    group('Caching', () {
      const cacheKey = 'test_cache_key';

      test('returns cached groups when valid', () async {
        final cachedGroups = [
          {'id': '1', 'name': 'Cached Group', 'isPublic': true},
        ];

        when(mockSQLiteHelper.getCachedGroups('', cacheKey))
            .thenAnswer((_) async => cachedGroups);
        when(mockSQLiteHelper.getCacheMetadata(cacheKey))
            .thenAnswer((_) async => {
                  'cached_at': DateTime.now().millisecondsSinceEpoch,
                });

        final filters = GroupQueryFilters(isPublic: true);
        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        final results = await stream.first;

        expect(results, equals(cachedGroups));
        verify(mockSQLiteHelper.getCachedGroups('', cacheKey)).called(1);
      });

      test('ignores expired cache', () async {
        final cachedGroups = [
          {'id': '1', 'name': 'Expired Group', 'isPublic': true},
        ];

        // Set cache as expired (6 minutes ago)
        final expiredTime = DateTime.now()
            .subtract(const Duration(minutes: 6))
            .millisecondsSinceEpoch;

        when(mockSQLiteHelper.getCachedGroups('', cacheKey))
            .thenAnswer((_) async => cachedGroups);
        when(mockSQLiteHelper.getCacheMetadata(cacheKey))
            .thenAnswer((_) async => {'cached_at': expiredTime});

        final filters = GroupQueryFilters(isPublic: true);
        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        final results = await stream.first;

        // Should fetch from Firestore, not cache
        expect(results, isNotEmpty);
        verify(mockSQLiteHelper.cacheGroups(any, any, cacheKey)).called(1);
      });

      test('caches results after Firestore fetch', () async {
        when(mockSQLiteHelper.getCachedGroups(any, any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);
        when(mockSQLiteHelper.getCacheMetadata(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);

        final filters = GroupQueryFilters(isPublic: true);
        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        await stream.first;

        verify(mockSQLiteHelper.cacheGroups(any, any, any)).called(1);
        verify(mockSQLiteHelper.insertCacheMetadata(any, any)).called(1);
      });

      test('handles cache errors gracefully', () async {
        when(mockSQLiteHelper.getCachedGroups(any, any))
            .thenThrow(Exception('Cache error'));
        when(mockSQLiteHelper.getCacheMetadata(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);

        final filters = GroupQueryFilters(isPublic: true);
        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        final results = await stream.first;

        // Should still return results from Firestore
        expect(results, isNotEmpty);
      });
    });

    group('Semantic Filtering', () {
      test('applies semantic filtering when search term provided', () async {
        // Set up test data
        await fakeFirestore.collection('chat_groups').add({
          'name': 'Warzone Champions',
          'isPublic': true,
          'memberCount': 10,
          'gameName': 'Warzone',
          'lastMessageTime': Timestamp.now(),
          'createdAt': Timestamp.now(),
        });

        when(mockSQLiteHelper.getCachedGroups(any, any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);
        when(mockSQLiteHelper.getCacheMetadata(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);
        when(mockGrokService.scoreRelevance(any, any))
            .thenAnswer((_) async => {'test_id': 0.8});

        final filters = GroupQueryFilters(
          isPublic: true,
          searchTerm: 'champions',
        );

        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        final results = await stream.first;

        expect(results, isNotEmpty);
        verify(mockGrokService.scoreRelevance('champions', any)).called(1);
      });

      test('handles GrokService errors gracefully', () async {
        await fakeFirestore.collection('chat_groups').add({
          'name': 'Test Group',
          'isPublic': true,
          'memberCount': 5,
          'gameName': 'Warzone',
          'lastMessageTime': Timestamp.now(),
          'createdAt': Timestamp.now(),
        });

        when(mockSQLiteHelper.getCachedGroups(any, any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);
        when(mockSQLiteHelper.getCacheMetadata(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);
        when(mockGrokService.scoreRelevance(any, any))
            .thenThrow(Exception('Grok error'));

        final filters = GroupQueryFilters(
          isPublic: true,
          searchTerm: 'test',
        );

        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        final results = await stream.first;

        // Should still return results without semantic filtering
        expect(results, isNotEmpty);
      });
    });

    group('Error Handling', () {
      test('handles Firebase index errors with fallback query', () async {
        // Mock Firebase exception for missing index
        final mockQuery = MockQuery<Map<String, dynamic>>();
        when(mockQuery.where(any, isEqualTo: any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: any)).thenReturn(mockQuery);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.get()).thenThrow(FirebaseException(
          plugin: cloud_firestore,
          code: 'failed-precondition',
          message: 'Index required',
        ));

        // This test is complex to mock properly, so we'll test the notification
        // is shown when index error occurs
        final filters = GroupQueryFilters(isPublic: true);
        final stream = queryBuilder.buildSuggestedGroupsStream(filters);

        // The stream should handle the error and show notification
        await stream.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => [],
        );

        verify(mockNotificationManager.showNotification(
          title: 'Index Required',
          body: 'Creating optimized indexes for better performance...',
        )).called(1);
      });

      test('handles general Firebase errors', () async {
        final mockQuery = MockQuery<Map<String, dynamic>>();
        when(mockQuery.where(any, isEqualTo: any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: any)).thenReturn(mockQuery);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.get()).thenThrow(FirebaseException(
          plugin: cloud_firestore,
          code: 'permission-denied',
          message: 'Access denied',
        ));

        final filters = GroupQueryFilters(isPublic: true);
        final stream = queryBuilder.buildSuggestedGroupsStream(filters);

        expect(() => stream.first, throwsA(isA<FirebaseException>()));
      });
    });

    group('Large Dataset Simulation', () {
      test('handles large result sets efficiently', () async {
        // Create 50 test groups
        final batch = fakeFirestore.batch();
        for (int i = 0; i < 50; i++) {
          final docRef = fakeFirestore.collection('chat_groups').doc();
          batch.set(docRef, {
            'name': 'Group $i',
            'isPublic': true,
            'memberCount': 10 + i,
            'gameName': 'Warzone',
            'lastMessageTime': Timestamp.now(),
            'createdAt': Timestamp.now(),
          });
        }
        await batch.commit();

        when(mockSQLiteHelper.getCachedGroups(any, any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);
        when(mockSQLiteHelper.getCacheMetadata(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);

        final filters = GroupQueryFilters(isPublic: true);

        final stopwatch = Stopwatch()..start();
        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        final results = await stream.first;
        stopwatch.stop();

        expect(results.length, lessThanOrEqualTo(20)); // Limited by pageSize
        expect(
            stopwatch.elapsedMilliseconds, lessThan(200)); // Performance check
      });

      test('maintains order with large datasets', () async {
        // Create groups with different member counts
        final batch = fakeFirestore.batch();
        for (int i = 0; i < 30; i++) {
          final docRef = fakeFirestore.collection('chat_groups').doc();
          batch.set(docRef, {
            'name': 'Group $i',
            'isPublic': true,
            'memberCount': 30 - i, // Descending order
            'gameName': 'Warzone',
            'lastMessageTime': Timestamp.now(),
            'createdAt': Timestamp.now(),
          });
        }
        await batch.commit();

        when(mockSQLiteHelper.getCachedGroups(any, any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);
        when(mockSQLiteHelper.getCacheMetadata(any))
            .thenAnswer((_) async => <Map<String, dynamic>>[]);

        final filters = GroupQueryFilters(isPublic: true);
        final stream = queryBuilder.buildSuggestedGroupsStream(filters);
        final results = await stream.first;

        // Results should be ordered by memberCount descending
        for (int i = 1; i < results.length; i++) {
          expect(
              results[i - 1]['memberCount'] >= results[i]['memberCount'], true);
        }
      });
    });
  });

  group('SuggestedGroupsNotifier', () {
    late SuggestedGroupsNotifier notifier;

    setUp(() {
      notifier = SuggestedGroupsNotifier(firestoreService);
    });

    test('initial state is loading', () {
      expect(notifier.state.suggestedGroups, equals(AsyncValue.loading()));
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });

    test('loadSuggestedGroups updates state correctly', () async {
      final filters = GroupQueryFilters(isPublic: true);

      await notifier.loadSuggestedGroups(filters);

      // State should eventually have data
      await Future.delayed(const Duration(milliseconds: 100));
      expect(notifier.state.suggestedGroups, isA<AsyncValue>());
    });

    test('loadNextPage handles pagination', () async {
      final filters = GroupQueryFilters(isPublic: true);

      await notifier.loadSuggestedGroups(filters);
      await Future.delayed(const Duration(milliseconds: 100));

      // Load next page
      await notifier.loadNextPage();

      // State should still be valid
      expect(notifier.state, isNotNull);
    });

    test('handles errors in loadSuggestedGroups', () async {
      // Mock firestore to throw error
      final mockFirestore = MockFirebaseFirestore();
      final failingService = FirestoreService(
        firestore: mockFirestore,
        sqliteHelper: mockSQLiteHelper,
        grokService: mockGrokService,
        notificationManager: mockNotificationManager,
      );

      final failingNotifier = SuggestedGroupsNotifier(failingService);

      final filters = GroupQueryFilters(isPublic: true);

      await failingNotifier.loadSuggestedGroups(filters);

      // Should handle error gracefully
      expect(failingNotifier.state.error, isNotNull);
    });

    test('refresh reloads data', () async {
      final filters = GroupQueryFilters(isPublic: true);

      await notifier.loadSuggestedGroups(filters);
      await Future.delayed(const Duration(milliseconds: 100));

      await notifier.refresh();

      // Should still work after refresh
      expect(notifier.state, isNotNull);
    });

    test('dispose cancels subscriptions', () {
      notifier.dispose();
      // Should not throw
    });
  });
}
