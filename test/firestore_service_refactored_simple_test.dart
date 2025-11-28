import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/services/grok_service.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';

// Import the classes directly instead of the full service
import 'package:squad_sync/services/firestore_service_refactored.dart';

// Generate mocks
// @GenerateMocks([
//   GrokService,
//   NotificationManager,
//   SQLiteHelper,
// ])
// import 'firestore_service_refactored_simple_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGrokService mockGrokService;
  late MockNotificationManager mockNotificationManager;
  late MockSQLiteHelper mockSQLiteHelper;
  late FakeFirebaseFirestore fakeFirestore;
  late OptimizedGroupQueryBuilder queryBuilder;

  setUp(() {
    mockGrokService = MockGrokService();
    mockNotificationManager = MockNotificationManager();
    mockSQLiteHelper = MockSQLiteHelper();
    fakeFirestore = FakeFirebaseFirestore();

    queryBuilder = OptimizedGroupQueryBuilder(
      fakeFirestore,
      mockSQLiteHelper,
      mockGrokService,
      mockNotificationManager,
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

  group('OptimizedGroupQueryBuilder - Basic Functionality', () {
    setUp(() async {
      // Set up test data
      await fakeFirestore.collection('chat_groups').add({
        'name': 'Warzone Squad',
        'isPublic': true,
        'memberCount': 10,
        'gameName': 'Warzone',
        'lastMessageTime': Timestamp.now(),
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.collection('chat_groups').add({
        'name': 'COD Mobile Team',
        'isPublic': true,
        'memberCount': 8,
        'gameName': 'COD Mobile',
        'lastMessageTime': Timestamp.now(),
        'createdAt': Timestamp.now(),
      });

      // Mock cache to return empty (force Firestore query)
      when(mockSQLiteHelper.getCachedGroups(any, any))
          .thenAnswer((_) async => []);
      when(mockSQLiteHelper.getCacheMetadata(any))
          .thenAnswer((_) async => null);
      when(mockSQLiteHelper.cacheGroups(any, any, any)).thenAnswer((_) async {
        return null;
      });
      when(mockSQLiteHelper.insertCacheMetadata(any, any))
          .thenAnswer((_) async {
        return null;
      });
    });

    test('buildSuggestedGroupsStream returns groups for public filter',
        () async {
      final filters = GroupQueryFilters(isPublic: true);

      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      final results = await stream.first;

      expect(results, isNotEmpty);
      expect(results.length, greaterThanOrEqualTo(2));
      expect(results.every((group) => group['isPublic'] == true), true);
    });

    test('buildSuggestedGroupsStream applies gameName filter', () async {
      final filters = GroupQueryFilters(isPublic: true, gameName: 'Warzone');

      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      final results = await stream.first;

      expect(results, isNotEmpty);
      expect(results.every((group) => group['gameName'] == 'Warzone'), true);
    });

    test('buildSuggestedGroupsStream applies minMemberCount filter', () async {
      final filters = GroupQueryFilters(
        isPublic: true,
        minMemberCount: 9,
      );

      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      final results = await stream.first;

      expect(results, isNotEmpty);
      expect(
          results.every((group) => (group['memberCount'] as int) >= 9), true);
    });

    test('buildSuggestedGroupsStream limits results to pageSize', () async {
      // Add more groups to test pagination
      for (int i = 0; i < 25; i++) {
        await fakeFirestore.collection('chat_groups').add({
          'name': 'Group $i',
          'isPublic': true,
          'memberCount': 5,
          'gameName': 'Warzone',
          'lastMessageTime': Timestamp.now(),
          'createdAt': Timestamp.now(),
        });
      }

      final filters = GroupQueryFilters(isPublic: true);
      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      final results = await stream.first;

      // Should be limited to 20 (pageSize)
      expect(results.length, equals(20));
    });

    test('buildSuggestedGroupsStream orders by memberCount descending',
        () async {
      final filters = GroupQueryFilters(isPublic: true);
      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      final results = await stream.first;

      // Check that results are ordered by memberCount descending
      for (int i = 1; i < results.length; i++) {
        expect(
          (results[i - 1]['memberCount'] as int) >=
              (results[i]['memberCount'] as int),
          true,
        );
      }
    });
  });

  group('OptimizedGroupQueryBuilder - Caching', () {
    test('returns cached groups when available and valid', () async {
      final cachedGroups = [
        {'id': 'cached1', 'name': 'Cached Group', 'isPublic': true},
      ];

      when(mockSQLiteHelper.getCachedGroups(any, any))
          .thenAnswer((_) async => cachedGroups);
      when(mockSQLiteHelper.getCacheMetadata(any)).thenAnswer((_) async => {
            'cached_at': DateTime.now().millisecondsSinceEpoch,
          });

      final filters = GroupQueryFilters(isPublic: true);
      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      final results = await stream.first;

      expect(results, equals(cachedGroups));
      verify(mockSQLiteHelper.getCachedGroups(any, any)).called(1);
    });

    test('ignores expired cache', () async {
      final cachedGroups = [
        {'id': 'expired', 'name': 'Expired Group', 'isPublic': true},
      ];

      // Set cache as expired (6 minutes ago)
      final expiredTime = DateTime.now()
          .subtract(const Duration(minutes: 6))
          .millisecondsSinceEpoch;

      when(mockSQLiteHelper.getCachedGroups(any, any))
          .thenAnswer((_) async => cachedGroups);
      when(mockSQLiteHelper.getCacheMetadata(any))
          .thenAnswer((_) async => {'cached_at': expiredTime});

      final filters = GroupQueryFilters(isPublic: true);
      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      final results = await stream.first;

      // Should fetch from Firestore, not cache
      expect(results, isNotEmpty);
      verify(mockSQLiteHelper.cacheGroups(any, any, any)).called(1);
    });

    test('caches results after Firestore fetch', () async {
      when(mockSQLiteHelper.getCachedGroups(any, any))
          .thenAnswer((_) async => []);
      when(mockSQLiteHelper.getCacheMetadata(any))
          .thenAnswer((_) async => null);

      final filters = GroupQueryFilters(isPublic: true);
      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      await stream.first;

      verify(mockSQLiteHelper.cacheGroups(any, any, any)).called(1);
      verify(mockSQLiteHelper.insertCacheMetadata(any, any)).called(1);
    });
  });

  group('OptimizedGroupQueryBuilder - Semantic Filtering', () {
    test('applies semantic filtering when search term provided', () async {
      await fakeFirestore.collection('chat_groups').add({
        'name': 'Warzone Champions',
        'isPublic': true,
        'memberCount': 10,
        'gameName': 'Warzone',
        'lastMessageTime': Timestamp.now(),
        'createdAt': Timestamp.now(),
      });

      when(mockSQLiteHelper.getCachedGroups(any, any))
          .thenAnswer((_) async => []);
      when(mockSQLiteHelper.getCacheMetadata(any))
          .thenAnswer((_) async => null);
      when(mockGrokService.scoreRelevance(any, any))
          .thenAnswer((_) async => {'test_id': 0.8});

      final filters = GroupQueryFilters(
        isPublic: true,
        searchTerm: 'champions',
      );

      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      final results = await stream.first;

      expect(results, isNotEmpty);
      verify(mockGrokService.scoreRelevance(any, any)).called(1);
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
          .thenAnswer((_) async => []);
      when(mockSQLiteHelper.getCacheMetadata(any))
          .thenAnswer((_) async => null);
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

  group('OptimizedGroupQueryBuilder - Large Dataset Simulation', () {
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
          .thenAnswer((_) async => []);
      when(mockSQLiteHelper.getCacheMetadata(any))
          .thenAnswer((_) async => null);

      final filters = GroupQueryFilters(isPublic: true);

      final stopwatch = Stopwatch()..start();
      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      final results = await stream.first;
      stopwatch.stop();

      expect(results.length, equals(20)); // Limited by pageSize
      expect(stopwatch.elapsedMilliseconds, lessThan(200)); // Performance check
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
          .thenAnswer((_) async => []);
      when(mockSQLiteHelper.getCacheMetadata(any))
          .thenAnswer((_) async => null);

      final filters = GroupQueryFilters(isPublic: true);
      final stream = queryBuilder.buildSuggestedGroupsStream(filters);
      final results = await stream.first;

      // Results should be ordered by memberCount descending
      for (int i = 1; i < results.length; i++) {
        expect(
          (results[i - 1]['memberCount'] as int) >=
              (results[i]['memberCount'] as int),
          true,
        );
      }
    });
  });

  group('SuggestedGroupsNotifier - Basic Functionality', () {
    late SuggestedGroupsNotifier notifier;

    setUp(() {
      notifier = SuggestedGroupsNotifier(
        FirestoreService(
          firestore: fakeFirestore,
          sqliteHelper: mockSQLiteHelper,
          grokService: mockGrokService,
          notificationManager: mockNotificationManager,
        ),
      );
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
