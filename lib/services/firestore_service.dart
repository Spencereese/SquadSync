import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'interfaces.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _changedFields = {};
  DateTime _lastUpdate = DateTime.now();
  static const int _updateInterval = 5;

  final Map<String, FirestoreFieldSerializer> _fieldSerializers = {};

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
}
