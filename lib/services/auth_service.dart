import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'interfaces.dart';

/// Service for handling authentication and user management
class AuthService implements IAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSubscription;

  /// Stream of authentication state changes
  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current user
  @override
  User? get currentUser => _auth.currentUser;

  /// Initialize auth service and set up listeners
  @override
  void initialize({
    required Function(User?) onAuthStateChanged,
  }) {
    _authSubscription = _auth.authStateChanges().listen(onAuthStateChanged);
  }

  /// Load display name from SharedPreferences or Firestore
  @override
  Future<String?> loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsName = prefs.getString('yourName');

    // Try to load from SharedPreferences first
    if (prefsName != null &&
        prefsName.trim().isNotEmpty &&
        prefsName != 'User') {
      return prefsName.trim();
    }

    // Fall back to Firestore
    final user = currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final firestoreName = userDoc.data()?['displayName'];
        if (firestoreName != null && firestoreName.trim().isNotEmpty) {
          return firestoreName.trim();
        }
      } catch (e) {
        debugPrint('Failed to load display name from Firestore: $e');
      }
    }

    return null;
  }

  /// Save display name to both SharedPreferences and Firestore
  @override
  Future<void> saveDisplayName(String displayName) async {
    final user = currentUser;
    if (user == null) return;

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yourName', displayName);

    // Save to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'displayName': displayName}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save display name to Firestore: $e');
    }
  }

  /// Load profile image from Firestore
  @override
  Future<String?> loadProfileImage() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return userDoc.data()?['profileImage'];
    } catch (e) {
      debugPrint('Failed to load profile image: $e');
      return null;
    }
  }

  /// Save profile image to Firestore
  @override
  Future<void> saveProfileImage(String? imageUrl) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'profileImage': imageUrl}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save profile image: $e');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Dispose of resources
  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
  }
}
