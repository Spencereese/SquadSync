import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'interfaces.dart';
import 'grok_service.dart';
import '../managers/stubs.dart';
import '../chat/sqlite_helper.dart';

/// QueryBuilder for building optimized discovery queries
class QueryBuilder {
  final FirebaseFirestore _firestore;

  QueryBuilder({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Builds a query for suggested groups with semantic filtering
  /// Cost: ~20 reads (limit 20), plus Grok API call for scoring
  Future<Stream<List<Map<String, dynamic>>>> buildSuggestedGroupsQuery(
    String searchTerm,
    String gameName,
    GrokService grokService,
    NotificationManager notificationManager,
    SQLiteHelper sqliteHelper,
  ) async {
    // First, try to get cached results from SQLite
    final cachedGroups =
        await sqliteHelper.getCachedGroups(gameName, searchTerm);
    if (cachedGroups.isNotEmpty) {
      // Return cached stream
      return Stream.value(cachedGroups);
    }

    // Build the optimized query with required indexes
    Query<Map<String, dynamic>> query =
        _firestore.collection('chat_groups').where('isPublic', isEqualTo: true);

    if (gameName.isNotEmpty) {
      query = query.where('gameName', isEqualTo: gameName);
    }

    query = query
        .orderBy('memberCount', descending: true)
        .orderBy('lastMessageTime', descending: true)
        .limit(20);

    try {
      final stream = query.snapshots();

      // Process results with semantic filtering
      return stream.asyncMap((snapshot) async {
        final docs = snapshot.docs;
        final groups = docs.map((d) => d.data()).toList();

        if (searchTerm.isNotEmpty && groups.isNotEmpty) {
          // Get relevance scores from Grok
          final groupNames = groups.map((g) => g['name'] as String).toList();
          final scores =
              await grokService.scoreRelevance(searchTerm, groupNames);

          // Filter and sort by relevance
          final scoredGroups = groups.map((group) {
            final name = group['name'] as String;
            final score = scores[name] ?? 0.0;
            return {'group': group, 'score': score};
          }).toList();

          scoredGroups.sort(
              (a, b) => (b['score'] as double).compareTo(a['score'] as double));

          final filteredGroups = scoredGroups
              .take(10)
              .map((s) => s['group'] as Map<String, dynamic>)
              .toList();

          // Cache the results
          await sqliteHelper.cacheGroups(filteredGroups, gameName, searchTerm);

          return filteredGroups;
        } else {
          // Cache without filtering
          await sqliteHelper.cacheGroups(groups, gameName, searchTerm);

          return groups;
        }
      });
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Index missing, fallback to simpler query
        notificationManager.showNotification(
            title: 'Search optimized', body: 'Creating index...');

        final fallbackQuery = _firestore
            .collection('chat_groups')
            .where('isPublic', isEqualTo: true)
            .limit(20);

        final stream = fallbackQuery.snapshots();

        // Cache fallback results
        return stream.map((snapshot) {
          final groups = snapshot.docs.map((d) => d.data()).toList();
          sqliteHelper.cacheGroups(groups, gameName, searchTerm);
          return groups;
        });
      }
      rethrow;
    }
  }
}

/// Generic field serializer for Firestore operations
class FirestoreFieldSerializer<T> {
  final String fieldName;
  final T Function() getter;
  final Map<String, dynamic> Function(T) converter;
  final T Function(Map<String, dynamic>)? deserializer;

  const FirestoreFieldSerializer({
    required this.fieldName,
    required this.getter,
    required this.converter,
    this.deserializer,
  });
}

/// Service for handling Firestore operations and data serialization
class FirestoreService implements IFirestoreService {
  final FirebaseFirestore _firestore;
  final Set<String> _changedFields = {};
  DateTime _lastUpdate = DateTime.now();
  static const int _updateInterval = 5;

  final Map<String, FirestoreFieldSerializer> _fieldSerializers = {};

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        queryBuilder = QueryBuilder(firestore: firestore);

  final QueryBuilder queryBuilder;

  /// Register a field serializer
  @override
  void registerField<T>(FirestoreFieldSerializer<T> serializer) {
    _fieldSerializers[serializer.fieldName] = serializer;
  }

  /// Mark a field as changed
  @override
  void markFieldChanged(String fieldName) {
    _changedFields.add(fieldName);
  }

  /// Check if a field should be updated
  bool _shouldUpdateField(String fieldName, bool force) {
    return force || _changedFields.contains(fieldName);
  }

  /// Serialize a map field with UID conversion (static helper)
  static Map<String, dynamic> serializeMapWithUidConversion(
    Map<String, dynamic> data,
    Map<String, String> displayNameCache,
  ) {
    return Map.fromEntries(
      data.entries
          .map((entry) {
            final uid = getUidForDisplayName(entry.key, displayNameCache);
            return uid != null ? MapEntry(uid, entry.value) : null;
          })
          .where((entry) => entry != null)
          .cast<MapEntry<String, dynamic>>(),
    );
  }

  /// Deserialize a map field with display name conversion (static helper)
  static Map<String, dynamic> deserializeMapWithDisplayNameConversion(
    Map<String, dynamic> data,
    Map<String, String> displayNameCache,
  ) {
    return Map.fromEntries(
      data.entries.map((entry) {
        final displayName = getDisplayNameForUid(entry.key, displayNameCache);
        return MapEntry(displayName, entry.value);
      }),
    );
  }

  /// Get UID for display name (static helper)
  static String? getUidForDisplayName(
      String displayName, Map<String, String> displayNameCache) {
    return displayNameCache.entries
            .firstWhere(
              (entry) => entry.value == displayName,
              orElse: () => const MapEntry('', ''),
            )
            .key
            .isNotEmpty
        ? displayNameCache.entries
            .firstWhere((entry) => entry.value == displayName)
            .key
        : null;
  }

  /// Get display name for UID (static helper)
  static String getDisplayNameForUid(
      String uid, Map<String, String> displayNameCache) {
    return displayNameCache[uid] ?? 'User';
  }

  /// Filter out empty collections
  Map<String, dynamic> _filterEmptyCollections(Map<String, dynamic> data) {
    return Map.fromEntries(
      data.entries.where((entry) {
        if (entry.value is Map) {
          return (entry.value as Map).isNotEmpty;
        } else if (entry.value is List) {
          return (entry.value as List).isNotEmpty;
        }
        return true;
      }),
    );
  }

  /// Update Firestore with changed data
  @override
  Future<void> updateFirestore({
    required Map<String, String> displayNameCache,
    bool force = false,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    final now = DateTime.now();
    if (!force && now.difference(_lastUpdate).inSeconds < _updateInterval) {
      return;
    }

    final data = <String, dynamic>{};

    // Process registered field serializers
    for (final serializer in _fieldSerializers.values) {
      if (_shouldUpdateField(serializer.fieldName, force)) {
        final value = serializer.getter();
        final converted = serializer.converter(value);
        if (converted.isNotEmpty) {
          data[serializer.fieldName] = converted;
        }
      }
    }

    // Filter out empty data
    final filteredData = _filterEmptyCollections(data);

    if (filteredData.isNotEmpty) {
      try {
        await _firestore
            .collection('squad')
            .doc('state')
            .set(filteredData, SetOptions(merge: true));
        _changedFields.clear();
        _lastUpdate = now;
      } catch (e) {
        // Firestore update failed - silently handled
      }
    }
  }

  /// Save game search results to Firestore for cross-device sync
  Future<void> saveGameSearch(
      String query, Map<String, dynamic> gameData) async {
    try {
      await _firestore
          .collection('game_searches')
          .doc(query)
          .set(gameData, SetOptions(merge: true));
    } catch (e) {
      // Silently handle Firestore save failures for game searches
      debugPrint('Failed to save game search to Firestore: $e');
    }
  }

  /// Load data from Firestore
  Future<Map<String, dynamic>> loadFirestoreData({
    required Map<String, String> displayNameCache,
  }) async {
    try {
      final doc = await _firestore.collection('squad').doc('state').get();
      if (!doc.exists) return {};

      final data = doc.data()!;
      final processedData = <String, dynamic>{};

      // Process registered field serializers for deserialization
      for (final serializer in _fieldSerializers.values) {
        if (data.containsKey(serializer.fieldName) &&
            serializer.deserializer != null) {
          processedData[serializer.fieldName] =
              serializer.deserializer!(data[serializer.fieldName]);
        }
      }

      return processedData;
    } catch (e) {
      return {};
    }
  }

  /// Create a serializer for simple map fields
  static FirestoreFieldSerializer<Map<String, dynamic>> createMapSerializer(
    String fieldName,
    Map<String, dynamic> Function() getter,
  ) {
    return FirestoreFieldSerializer<Map<String, dynamic>>(
      fieldName: fieldName,
      getter: getter,
      converter: (data) => data,
    );
  }

  /// Create a serializer for map fields that need UID conversion
  static FirestoreFieldSerializer<Map<String, dynamic>>
      createMapWithUidSerializer(
    String fieldName,
    Map<String, dynamic> Function() getter,
    Map<String, String> displayNameCache,
  ) {
    return FirestoreFieldSerializer<Map<String, dynamic>>(
      fieldName: fieldName,
      getter: getter,
      converter: (data) =>
          serializeMapWithUidConversion(data, displayNameCache),
      deserializer: (data) =>
          deserializeMapWithDisplayNameConversion(data, displayNameCache),
    );
  }

  @override
  Future<Map<String, dynamic>?> loadFirestore(
      String collection, String document) async {
    try {
      final doc = await _firestore.collection(collection).doc(document).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Voice room methods
  @override
  Stream<Map<String, dynamic>?> getVoiceRoomStream(String roomId) {
    return _firestore
        .collection('voice_rooms')
        .doc(roomId)
        .snapshots()
        .map((doc) => doc.data());
  }

  @override
  Future<void> updateVoiceRoom(String roomId, Map<String, dynamic> data) async {
    await _firestore
        .collection('voice_rooms')
        .doc(roomId)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<void> updateVoiceParticipant(
      String roomId, String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('voice_rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }
}
