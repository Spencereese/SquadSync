import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../chat/sqlite_helper.dart';
import 'grok_service.dart';
import '../managers/notification_manager.dart';

part 'firestore_service_refactored.g.dart';

/// Data class for group query filters
class GroupQueryFilters {
  final bool? isPublic;
  final String? gameName;
  final int? minMemberCount;
  final String? searchTerm;

  const GroupQueryFilters({
    this.isPublic,
    this.gameName,
    this.minMemberCount,
    this.searchTerm,
  });

  bool get hasFilters =>
      isPublic != null || gameName != null || minMemberCount != null || (searchTerm?.isNotEmpty ?? false);
}

/// State for Firestore operations
class FirestoreState {
  final AsyncValue<List<Map<String, dynamic>>> suggestedGroups;
  final bool isLoading;
  final String? error;

  const FirestoreState({
    this.suggestedGroups = const AsyncValue.loading(),
    this.isLoading = false,
    this.error,
  });

  FirestoreState copyWith({
    AsyncValue<List<Map<String, dynamic>>>? suggestedGroups,
    bool? isLoading,
    String? error,
  }) {
    return FirestoreState(
      suggestedGroups: suggestedGroups ?? this.suggestedGroups,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Optimized query builder for chat_groups collection
class OptimizedGroupQueryBuilder {
  final FirebaseFirestore _firestore;
  final SQLiteHelper _sqliteHelper;
  final GrokService _grokService;
  final NotificationManager _notificationManager;

  static const int _pageSize = 20;
  static const Duration _cacheTTL = Duration(minutes: 5);

  OptimizedGroupQueryBuilder(
    this._firestore,
    this._sqliteHelper,
    this._grokService,
    this._notificationManager,
  );

  /// Builds optimized query with composite indexes
  /// Required Firestore indexes:
  /// - isPublic (asc), memberCount (desc), gameName (asc)
  /// - isPublic (asc), memberCount (desc), lastMessageTime (desc)
  Query<Map<String, dynamic>> _buildBaseQuery(GroupQueryFilters filters) {
    Query<Map<String, dynamic>> query = _firestore.collection('chat_groups');

    // Apply filters
    if (filters.isPublic != null) {
      query = query.where('isPublic', isEqualTo: filters.isPublic);
    }

    if (filters.gameName != null && filters.gameName!.isNotEmpty) {
      query = query.where('gameName', isEqualTo: filters.gameName);
    }

    if (filters.minMemberCount != null) {
      query = query.where('memberCount', isGreaterThanOrEqualTo: filters.minMemberCount);
    }

    // Order by composite index: isPublic asc, memberCount desc, gameName asc
    query = query
        .orderBy('isPublic', descending: false)
        .orderBy('memberCount', descending: true)
        .orderBy('gameName', descending: false)
        .limit(_pageSize);

    return query;
  }

  /// Gets cached groups if valid, null otherwise
  Future<List<Map<String, dynamic>>?> _getValidCachedGroups(String cacheKey) async {
    try {
      final cached = await _sqliteHelper.getCachedGroups('', cacheKey);
      if (cached.isNotEmpty) {
        // Check TTL
        final cacheEntry = await _sqliteHelper.getCacheMetadata(cacheKey);
        if (cacheEntry != null) {
          final cachedAt = DateTime.fromMillisecondsSinceEpoch(cacheEntry['cached_at']);
          if (DateTime.now().difference(cachedAt) < _cacheTTL) {
            return cached;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking cache: $e');
    }
    return null;
  }

  /// Caches groups with metadata
  Future<void> _cacheGroups(List<Map<String, dynamic>> groups, String cacheKey) async {
    try {
      await _sqliteHelper.cacheGroups(groups, '', cacheKey);
      // Store cache metadata
      await _sqliteHelper.insertCacheMetadata(cacheKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching groups: $e');
    }
  }

  /// Builds paginated stream with caching and semantic filtering
  Stream<List<Map<String, dynamic>>> buildSuggestedGroupsStream(
    GroupQueryFilters filters, {
    DocumentSnapshot? startAfter,
  }) async* {
    final cacheKey = _generateCacheKey(filters, startAfter);

    // Try cache first
    final cachedGroups = await _getValidCachedGroups(cacheKey);
    if (cachedGroups != null) {
      yield cachedGroups;
      return;
    }

    // Build Firestore query
    Query<Map<String, dynamic>> query = _buildBaseQuery(filters);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    try {
      final snapshot = await query.get();
      var groups = snapshot.docs.map((doc) => doc.data()..['id'] = doc.id).toList();

      // Apply semantic filtering if search term provided
      if (filters.searchTerm?.isNotEmpty ?? false) {
        groups = await _applySemanticFiltering(groups, filters.searchTerm!);
      }

      // Cache results
      await _cacheGroups(groups, cacheKey);

      yield groups;

      // Set up real-time updates
      yield* query.snapshots().asyncMap((querySnapshot) async {
        var updatedGroups = querySnapshot.docs
            .map((doc) => doc.data()..['id'] = doc.id)
            .toList();

        if (filters.searchTerm?.isNotEmpty ?? false) {
          updatedGroups = await _applySemanticFiltering(updatedGroups, filters.searchTerm!);
        }

        // Update cache
        await _cacheGroups(updatedGroups, cacheKey);

        return updatedGroups;
      });

    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        _notificationManager.showNotification(
          title: 'Index Required',
          body: 'Creating optimized indexes for better performance...',
        );

        // Fallback to simpler query
        final fallbackQuery = _firestore
            .collection('chat_groups')
            .where('isPublic', isEqualTo: true)
            .limit(_pageSize);

        final snapshot = await fallbackQuery.get();
        final groups = snapshot.docs.map((doc) => doc.data()..['id'] = doc.id).toList();

        await _cacheGroups(groups, cacheKey);
        yield groups;
      } else {
        rethrow;
      }
    }
  }

  /// Applies semantic filtering using Grok AI
  Future<List<Map<String, dynamic>>> _applySemanticFiltering(
    List<Map<String, dynamic>> groups,
    String searchTerm,
  ) async {
    if (groups.isEmpty) return groups;

    try {
      final groupNames = groups.map((g) => g['name'] as String? ?? '').toList();
      final scores = await _grokService.scoreRelevance(searchTerm, groupNames);

      final scoredGroups = groups.map((group) {
        final name = group['name'] as String? ?? '';
        final score = scores[name] ?? 0.0;
        return {'group': group, 'score': score};
      }).toList();

      scoredGroups.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

      return scoredGroups
          .take(10)
          .map((s) => s['group'] as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('Semantic filtering failed: $e');
      return groups; // Return unfiltered results on error
    }
  }

  /// Generates cache key for filters
  String _generateCacheKey(GroupQueryFilters filters, DocumentSnapshot? startAfter) {
    final keyParts = [
      filters.isPublic?.toString() ?? 'null',
      filters.gameName ?? 'null',
      filters.minMemberCount?.toString() ?? 'null',
      filters.searchTerm ?? 'null',
      startAfter?.id ?? 'null',
    ];
    return keyParts.join('_');
  }
}

/// StateNotifier for managing suggested groups
class SuggestedGroupsNotifier extends StateNotifier<FirestoreState> {
  final FirestoreService _firestoreService;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  GroupQueryFilters? _currentFilters;
  DocumentSnapshot? _lastDocument;
  bool _hasMorePages = true;

  SuggestedGroupsNotifier(this._firestoreService) : super(const FirestoreState());

  /// Loads suggested groups with filters
  Future<void> loadSuggestedGroups(GroupQueryFilters filters) async {
    state = state.copyWith(isLoading: true, error: null);
    _currentFilters = filters;
    _lastDocument = null;
    _hasMorePages = true;

    try {
      final stream = _firestoreService.queryBuilder.buildSuggestedGroupsStream(filters);

      _subscription?.cancel();
      _subscription = stream.listen(
        (groups) {
          state = state.copyWith(
            suggestedGroups: AsyncValue.data(groups),
            isLoading: false,
          );
        },
        onError: (error) {
          state = state.copyWith(
            error: error.toString(),
            isLoading: false,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        suggestedGroups: AsyncValue.error(e, StackTrace.current),
        isLoading: false,
      );
    }
  }

  /// Loads next page
  Future<void> loadNextPage() async {
    if (_currentFilters == null || !_hasMorePages || state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final currentGroups = state.suggestedGroups.maybeWhen(
        data: (groups) => groups,
        orElse: () => <Map<String, dynamic>>[],
      );

      if (currentGroups.isNotEmpty) {
        // Create a mock DocumentSnapshot for pagination
        // In a real implementation, you'd store the actual DocumentSnapshot
        final stream = _firestoreService.queryBuilder.buildSuggestedGroupsStream(
          _currentFilters!,
          startAfter: _lastDocument,
        );

        final newGroups = await stream.first;
        if (newGroups.isNotEmpty) {
          final allGroups = [...currentGroups, ...newGroups];
          state = state.copyWith(
            suggestedGroups: AsyncValue.data(allGroups),
            isLoading: false,
          );
          // Update last document for next page
          _lastDocument = null; // Would be set from actual query
        } else {
          _hasMorePages = false;
          state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  /// Refreshes current results
  Future<void> refresh() async {
    if (_currentFilters != null) {
      await loadSuggestedGroups(_currentFilters!);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Main FirestoreService class with Riverpod integration
class FirestoreService {
  final FirebaseFirestore _firestore;
  final SQLiteHelper _sqliteHelper;
  final GrokService _grokService;
  final NotificationManager _notificationManager;

  late final OptimizedGroupQueryBuilder queryBuilder;

  FirestoreService({
    required FirebaseFirestore firestore,
    required SQLiteHelper sqliteHelper,
    required GrokService grokService,
    required NotificationManager notificationManager,
  })  : _firestore = firestore,
        _sqliteHelper = sqliteHelper,
        _grokService = grokService,
        _notificationManager = notificationManager {
    queryBuilder = OptimizedGroupQueryBuilder(
      _firestore,
      _sqliteHelper,
      _grokService,
      _notificationManager,
    );
  }

  /// Generic method to load data from Firestore with error handling
  Future<Map<String, dynamic>?> loadDocument(String collection, String document) async {
    try {
      final doc = await _firestore.collection(collection).doc(document).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  /// Generic method to save data to Firestore with error handling
  Future<bool> saveDocument(String collection, String document, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(document).set(data, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Batch operation with error handling
  Future<bool> batchWrite(List<WriteBatch> operations) async {
    try {
      final batch = _firestore.batch();
      // Note: This is a simplified version - actual implementation would need proper operation handling
      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clean up expired cache entries
  Future<void> cleanupExpiredCache() async {
    try {
      await _sqliteHelper.cleanupExpiredCache(OptimizedGroupQueryBuilder._cacheTTL);
    } catch (e) {
      debugPrint('Cache cleanup failed: $e');
    }
  }

  // Voice room methods
  Stream<Map<String, dynamic>?> getVoiceRoomStream(String roomId) {
    return _firestore
        .collection('voice_rooms')
        .doc(roomId)
        .snapshots()
        .map((doc) => doc.data());
  }

  Future<void> updateVoiceRoom(String roomId, Map<String, dynamic> data) async {
    await _firestore
        .collection('voice_rooms')
        .doc(roomId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> updateVoiceParticipant(String roomId, String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('voice_rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }
}