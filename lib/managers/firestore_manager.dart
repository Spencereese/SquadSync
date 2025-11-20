import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/app_flow_manager.dart';

/// Manages Firestore data persistence and synchronization
class FirestoreManager with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Map<String, dynamic> _cachedData = {};
  bool _isOnline = true;

  // Analytics tracking
  final Map<String, DateTime> _queryStartTimes = {};
  AppFlowManager? _appFlowManager;

  bool get isOnline => _isOnline;

  void setOnlineStatus(bool online) {
    _isOnline = online;
    notifyListeners();
  }

  /// Set AppFlowManager for discovery metrics tracking
  void setAppFlowManager(AppFlowManager appFlowManager) {
    _appFlowManager = appFlowManager;
  }

  /// Start tracking query duration
  void _startQueryTracking(String queryId) {
    _queryStartTimes[queryId] = DateTime.now();
  }

  /// End tracking and log query duration
  Future<void> _endQueryTracking(String queryId, String queryType,
      {bool hadError = false}) async {
    final startTime = _queryStartTimes.remove(queryId);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      await _analytics.logEvent(
        name: 'query_duration',
        parameters: {
          'query_type': queryType,
          'duration_ms': duration.inMilliseconds,
          'had_error': hadError,
        },
      );
    }
  }

  /// Log index error event
  Future<void> _logIndexError(String queryType, String errorMessage) async {
    await _analytics.logEvent(
      name: 'index_error',
      parameters: {
        'query_type': queryType,
        'error_message': errorMessage,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Track discovery metrics (search-to-join conversion)
  Future<void> trackDiscoveryConversion({
    required String userId,
    required String searchTerm,
    required String gameName,
    required bool resultedInJoin,
    required int groupsViewed,
  }) async {
    await _appFlowManager?.trackGroupDiscoveryConversion(
      userId: userId,
      searchTerm: searchTerm,
      gameName: gameName,
      joinedSquadId: resultedInJoin ? 'converted' : 'not_converted',
      joinedSquadName: resultedInJoin ? 'converted_squad' : 'not_converted',
      groupsViewedBeforeJoin: groupsViewed,
    );
  }

  /// Track group discovery search
  Future<void> trackGroupDiscoverySearch({
    required String userId,
    required String searchTerm,
    required String gameName,
    required int resultsCount,
    required Duration searchDuration,
  }) async {
    await _appFlowManager?.trackGroupDiscoverySearch(
      userId: userId,
      searchTerm: searchTerm,
      gameName: gameName,
      resultsCount: resultsCount,
      searchDuration: searchDuration,
    );
  }

  Future<void> saveSquadData(String squadId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('squads').doc(squadId).set(data);
      _cachedData[squadId] = data;
      notifyListeners();
    } catch (e) {
      // Handle offline scenario
      _cachedData[squadId] = data;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> loadSquadData(String squadId) async {
    try {
      final doc = await _firestore.collection('squads').doc(squadId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _cachedData[squadId] = data;
        notifyListeners();
        return data;
      }
    } catch (e) {
      // Return cached data if offline
      return _cachedData[squadId];
    }
    return null;
  }

  Future<void> saveUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).set(data);
      notifyListeners();
    } catch (e) {
      // Handle offline scenario
    }
  }

  Future<Map<String, dynamic>?> loadUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveChatMessage(
      String squadId, Map<String, dynamic> message) async {
    try {
      await _firestore
          .collection('chats')
          .doc(squadId)
          .collection('messages')
          .add(message);
      notifyListeners();
    } catch (e) {
      // Handle offline scenario
    }
  }

  Stream<QuerySnapshot> getChatMessages(String squadId) {
    return _firestore
        .collection('chats')
        .doc(squadId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> addScheduleEvent(Map<String, dynamic> event) async {
    try {
      await _firestore.collection('schedules').add(event);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add schedule event: $e');
      rethrow;
    }
  }

  Future<void> voteForScheduleEvent(String eventId) async {
    try {
      await _firestore
          .collection('schedules')
          .doc(eventId)
          .update({'votes': FieldValue.increment(1)});
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to vote for event: $e');
      rethrow;
    }
  }

  Future<void> deleteScheduleEvent(String eventId) async {
    try {
      await _firestore.collection('schedules').doc(eventId).delete();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete event: $e');
      rethrow;
    }
  }

  Future<List<QueryDocumentSnapshot>> getUserScheduleEvents(
      String playerUid) async {
    try {
      final snapshot = await _firestore
          .collection('schedules')
          .where('player', isEqualTo: playerUid)
          .get();
      return snapshot.docs;
    } catch (e) {
      debugPrint('Failed to get user events: $e');
      return [];
    }
  }

  Future<void> sendInvite(Map<String, dynamic> invite) async {
    try {
      await _firestore.collection('invites').add(invite);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to send invite: $e');
      rethrow;
    }
  }

  Future<List<String>> getSquadMembers(String squadId) async {
    try {
      final doc = await _firestore.collection('squad').doc('state').get();
      if (doc.exists) {
        final data = doc.data()!;
        return List<String>.from(data['members'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get squad members: $e');
      return [];
    }
  }

  Future<void> syncOfflineData() async {
    // Implementation for syncing cached data when coming back online
    notifyListeners();
  }

  Future<void> backupData() async {
    // Implementation for data backup
    notifyListeners();
  }

  Future<void> restoreData() async {
    // Implementation for data restoration
    notifyListeners();
  }

  /// Checks for required Firestore indexes and logs console links for manual creation if missing
  void checkForRequiredIndexes() {
    // This method is called when a FirestoreException with code 'failed-precondition' is caught
    // It logs links to create the required indexes manually
    final projectId = Firebase.app().options.projectId;
    debugPrint('Missing required Firestore indexes. Create them at:');
    debugPrint(
        '1. For suggested groups by public status, member count, and last message time:');
    debugPrint(
        'https://console.firebase.google.com/project/$projectId/firestore/indexes?create_composite=isPublic%20ASCENDING%2CmemberCount%20DESCENDING%2ClastMessageTime%20DESCENDING');
    debugPrint(
        '2. For suggested groups by game, public status, and member count:');
    debugPrint(
        'https://console.firebase.google.com/project/$projectId/firestore/indexes?create_composite=gameName%20ASCENDING%2CisPublic%20ASCENDING%2CmemberCount%20DESCENDING');
    debugPrint('3. For user-owned groups by creator and creation time:');
    debugPrint(
        'https://console.firebase.google.com/project/$projectId/firestore/indexes?create_composite=createdBy%20ASCENDING%2CcreatedAt%20DESCENDING');
  }

  /// Store vector embeddings for a chat group
  Future<void> storeGroupEmbeddings(
      String groupId, List<double> embeddings) async {
    try {
      await _firestore.collection('chat_groups').doc(groupId).update({
        'embedding': embeddings,
      });
    } catch (e) {
      debugPrint('Failed to store embeddings for group $groupId: $e');
    }
  }

  /// Get suggested groups using vector similarity search
  Future<List<Map<String, dynamic>>> getSuggestedGroups(
    String searchTerm,
    String gameName,
    List<double> queryEmbedding,
  ) async {
    final queryId = 'suggested_groups_${DateTime.now().millisecondsSinceEpoch}';
    _startQueryTracking(queryId);

    try {
      // Try vector search if available (Firebase Vector Search)
      // For now, fallback to client-side similarity
      Query query = _firestore
          .collection('chat_groups')
          .where('isPublic', isEqualTo: true)
          .where('gameName', isEqualTo: gameName)
          .limit(50); // Get more for client-side filtering

      if (kDebugMode) {
        debugPrint('Firestore Query: ${query.toString()}');
      }

      final snapshot = await query.get();

      final groups = snapshot.docs
          .map((doc) => <String, dynamic>{
                ...(doc.data() as Map<String, dynamic>? ?? <String, dynamic>{}),
                'id': doc.id,
              })
          .toList();

      // Filter by embedding similarity
      final scoredGroups = groups.where((group) {
        final embedding = List<double>.from(group['embedding'] ?? []);
        if (embedding.isEmpty) return false;
        final similarity = _cosineSimilarity(queryEmbedding, embedding);
        return similarity > 0.7; // Threshold for relevance
      }).map((group) {
        final embedding = List<double>.from(group['embedding'] ?? []);
        final similarity = _cosineSimilarity(queryEmbedding, embedding);
        return {
          ...group,
          'similarity': similarity,
        };
      }).toList();

      // Sort by similarity and limit
      scoredGroups.sort((a, b) =>
          (b['similarity'] as double).compareTo(a['similarity'] as double));
      final result = scoredGroups.take(20).toList();

      await _endQueryTracking(queryId, 'suggested_groups');
      return result;
    } on FirebaseException catch (e) {
      await _logIndexError('suggested_groups', e.message ?? 'Unknown error');

      if (e.code == 'failed-precondition') {
        checkForRequiredIndexes();
        // Fallback to basic query
        Query fallbackQuery = _firestore
            .collection('chat_groups')
            .where('isPublic', isEqualTo: true)
            .limit(20);

        if (kDebugMode) {
          debugPrint('Fallback Firestore Query: ${fallbackQuery.toString()}');
        }

        final snapshot = await fallbackQuery.get();
        final result = snapshot.docs
            .map((doc) => <String, dynamic>{
                  ...(doc.data() as Map<String, dynamic>? ??
                      <String, dynamic>{}),
                  'id': doc.id,
                })
            .toList();

        await _endQueryTracking(queryId, 'suggested_groups_fallback',
            hadError: true);
        return result;
      }
      await _endQueryTracking(queryId, 'suggested_groups', hadError: true);
      rethrow;
    }
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Simulate index error for testing purposes
  /// This method throws a FirebaseException with 'failed-precondition' code
  /// to test index error handling
  Future<void> simulateIndexError() async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'failed-precondition',
      message: 'Simulated index error for testing',
    );
  }
}
