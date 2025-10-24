import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages Firestore data persistence and synchronization
class FirestoreManager with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, dynamic> _cachedData = {};
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  void setOnlineStatus(bool online) {
    _isOnline = online;
    notifyListeners();
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
}
