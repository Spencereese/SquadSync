import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Load display name from Firebase Auth, SharedPreferences or Firestore
  @override
  Future<String?> loadDisplayName() async {
    final user = currentUser;

    // Try to load from Firebase Auth first
    if (user != null &&
        user.displayName != null &&
        user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }

    final prefs = await SharedPreferences.getInstance();
    final prefsName = prefs.getString('yourName');

    // Try to load from SharedPreferences
    if (prefsName != null &&
        prefsName.trim().isNotEmpty &&
        prefsName != 'User') {
      return prefsName.trim();
    }

    // Fall back to Firestore
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
        // Failed to load display name from Firestore - silently handled
      }
    }

    return null;
  }

  /// Save display name to Firebase Auth, SharedPreferences and Firestore
  @override
  Future<void> saveDisplayName(String displayName) async {
    final user = currentUser;
    if (user == null) return;

    // Save to Firebase Auth
    await user.updateProfile(displayName: displayName);

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
      // Failed to save display name to Firestore - silently handled
    }
  }

  /// Load profile image from Firebase Auth or Firestore
  @override
  Future<String?> loadProfileImage() async {
    final user = currentUser;
    if (user == null) return null;

    // Try to load from Firebase Auth first
    if (user.photoURL != null && user.photoURL!.trim().isNotEmpty) {
      return user.photoURL!.trim();
    }

    // Fall back to Firestore
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return userDoc.data()?['profileImage'];
    } catch (e) {
      return null;
    }
  }

  /// Save profile image to Firebase Auth and Firestore
  @override
  Future<void> saveProfileImage(String? imageUrl) async {
    final user = currentUser;
    if (user == null) return;

    // Save to Firebase Auth
    await user.updateProfile(photoURL: imageUrl);

    // Save to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'profileImage': imageUrl}, SetOptions(merge: true));
    } catch (e) {
      // Failed to save profile image - silently handled
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
