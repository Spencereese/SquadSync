import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';

class SquadPersistenceManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService firestoreService = FirestoreService();

  // Persistence state
  bool _isInitialized = false;
  bool _isInitialDataLoaded = false;
  String? _profileImage;
  String? _displayName;
  final Map<String, String?> _memberProfileImages = {};
  final List<String> _changedFields = [];
  DateTime _lastFirestoreUpdate = DateTime.now();
  final Duration _firestoreUpdateInterval = const Duration(seconds: 5);

  // Getters
  // ignore: unnecessary_getters_setters
  bool get isInitialized => _isInitialized;
  // ignore: unnecessary_getters_setters
  bool get isInitialDataLoaded => _isInitialDataLoaded;
  // ignore: unnecessary_getters_setters
  String? get profileImage => _profileImage;
  // ignore: unnecessary_getters_setters
  String? get displayName => _displayName;
  // ignore: unnecessary_getters_setters
  Map<String, String?> get memberProfileImages => _memberProfileImages;

  // Setters
  // ignore: unnecessary_getters_setters
  set isInitialized(bool value) => _isInitialized = value;
  // ignore: unnecessary_getters_setters
  set isInitialDataLoaded(bool value) => _isInitialDataLoaded = value;
  // ignore: unnecessary_getters_setters
  set profileImage(String? value) => _profileImage = value;
  // ignore: unnecessary_getters_setters
  set displayName(String? value) => _displayName = value;

  // Initialization
  Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsName = prefs.getString('yourName');

      // Load from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final displayNameFromDoc = userDoc.data()?['displayName'];

      if (prefsName != null &&
          prefsName.trim().isNotEmpty &&
          prefsName != 'User') {
        _displayName = prefsName.trim();
      } else if (displayNameFromDoc != null &&
          displayNameFromDoc.trim().isNotEmpty) {
        _displayName = displayNameFromDoc.trim();
        await prefs.setString('yourName', _displayName!);
      } else {
        _displayName = 'User';
      }

      _profileImage = userDoc.data()?['profileImage'];
    }
    _isInitialized = true;
  }

  // Load user squads
  Future<void> loadUserSquads(List<String> userSquadIds,
      Map<String, Map<String, dynamic>> userSquads) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final query = await _firestore
          .collection('squads')
          .where('members', arrayContains: user.uid)
          .get();
      userSquadIds.clear();
      userSquadIds.addAll(query.docs.map((doc) => doc.id));
      userSquads.clear();
      userSquads.addAll({for (var doc in query.docs) doc.id: doc.data()});
    }
  }

  // Load member display names
  Future<void> loadMemberDisplayNames(List<String> squadMemberUids,
      Map<String, String> memberDisplayNames) async {
    if (squadMemberUids.isEmpty) return;

    final futures = squadMemberUids
        .where((uid) => !memberDisplayNames.containsKey(uid))
        .map((uid) async {
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final displayName = userDoc.data()?['displayName'] ?? 'User';
        memberDisplayNames[uid] = displayName;
      } catch (e) {
        memberDisplayNames[uid] = 'User';
      }
    });

    await Future.wait(futures);
  }

  // Sync spots from squad subcollection
  Future<void> syncSpotsFromSquad(
      String? selectedSquadId,
      Map<String, List<String?>> gameSquadSpots,
      Map<String, dynamic>? currentGame) async {
    if (selectedSquadId == null) return;
    final spotsSnapshot = await _firestore
        .collection('squads')
        .doc(selectedSquadId)
        .collection('spots')
        .get();
    final gameName = currentGame?['name'] ?? '';
    gameSquadSpots[gameName] = List<String?>.filled(8, null);
    for (var doc in spotsSnapshot.docs) {
      final index = int.tryParse(doc.id);
      if (index != null && index < 8) {
        gameSquadSpots[gameName]![index] = doc.data()['uid'];
      }
    }
  }

  // Update Firestore
  Future<void> updateFirestoreAsync({
    required Map<String, String> memberDisplayNames,
    bool force = false,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final now = DateTime.now();
    if (force ||
        now.difference(_lastFirestoreUpdate).inSeconds >=
            _firestoreUpdateInterval.inSeconds) {
      // Simplified: just call the service
      try {
        await firestoreService.updateFirestore(
            displayNameCache: memberDisplayNames, force: force);
        _changedFields.clear();
        _lastFirestoreUpdate = now;
      } catch (e) {
        debugPrint("Firestore update failed: $e");
      }
    }
  }

  void updateFirestore({bool force = false}) {
    // This would need the data maps passed in, but for simplicity, assume it's called from SquadState
  }

  // Mark field changed
  void markFieldChanged(String field) {
    if (!_changedFields.contains(field)) {
      _changedFields.add(field);
    }
  }

  // Update profile image
  void updateProfileImage(String url) {
    _profileImage = url;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firestore
          .collection('users')
          .doc(user.uid)
          .set({'profileImage': url}, SetOptions(merge: true));
    }
  }

  // Update display name
  Future<void> updateDisplayName(String name) async {
    _displayName = name;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'displayName': name}, SetOptions(merge: true));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yourName', name);
  }
}
